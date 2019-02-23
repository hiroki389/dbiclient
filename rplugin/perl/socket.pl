#
# Server side script
#
use strict;
use warnings;
use utf8;
use File::Basename;
use Carp ();
use Encode;
use Encode::Guess;
use IO::Handle;
use IO::Socket;
use JSON;
use DBI;
use Data::Dumper;
use Devel::Peek;
#use Devel::Size qw(size total_size);
use Time::HiRes;  
use File::Path;
BEGIN { push @INC, dirname($0) }
use DBIxEncoding;
$Data::Dumper::Indent = 0;
$Data::Dumper::Useqq = 1;
$Data::Dumper::Terse = 1;
$Data::Dumper::Pair = ":";

my $client_socket;
my $dbh;
my $sth;
my $server_socket;
my $datasource;
my $user="";
my $pass;
my $limitrows;
my $oracleflg;
my $odbcflg;
my $postgresflg;
my $envdict;
my $dbencoding;
my $primarykeyflg;
my $g_primary_key={};
my $g_columns={};
my $g_columns_result={};
my $port=shift;
my $basedir=shift;
my $vimencoding=shift;

sub outputlog{
    my $msg=shift;
    my $pid=shift;
    my $sig=shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon += 1;
    my $date=sprintf("%04d/%02d/%02d %02d:%02d:%02d",$year,$mon,$mday,$hour,$min,$sec);
    if(defined($pid)){
        $pid=" PORT:" . $pid;
    }else{
        $pid="";
    }
    if(defined($sig)){
        $sig=" SIGNAL:" . $sig;
    }else{
        $sig="";
    }
    print LOGFILE $date . $pid . $sig . " " . $msg . "\n";
}

sub getdate{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon += 1;
    return sprintf("%04d%02d%02d",$year,$mon,$mday);
}
sub getdatetime{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon += 1;
    return sprintf("%04d%02d%02d%02d%02d%02d",$year,$mon,$mday,$hour,$min,$sec);
}
sub disconnect{
    if(defined($dbh)){
        $dbh->rollback;
        $dbh->disconnect;
        undef($dbh);
        outputlog("DISCONNECT",$port);
    }
}
sub exitfunc{
    disconnect();
    if(defined($client_socket)){
        $client_socket->close;
    }
    if(defined($server_socket)){
        $server_socket->close;
    }
    close(LOGFILE);
    exit(0);
}
sub cancel{
    if(defined($sth)){
        outputlog("cancel",$port);
        $sth->finish;
    }
}
$SIG{HUP} = $SIG{TERM} = $SIG{KILL} = $SIG{QUIT} =\&exitfunc;
$SIG{INT} = \&cancel;

binmode STDIN,  (":encoding(" . $vimencoding . ')');
binmode STDOUT,  (":encoding(" . $vimencoding . ')');
STDERR->autoflush;
STDOUT->autoflush;
LOGFILE->autoflush;

eval {
    if (-e $basedir) {
    } else {
        mkpath([$basedir]) or warn $!;
    }
};
if ($@) {
  die $@;
}
open(LOGFILE,'>>',"${basedir}/socket_" . getdate . ".log") or die("error :$!");
binmode LOGFILE,  (":encoding(" . $vimencoding . ')');
$server_socket = IO::Socket::INET->new(
    LocalPort => $port, 
    Proto     => 'tcp', 
    Listen    => 1,     
    ReuseAddr => 1,     
) or die $!;

Carp::croak "Could not create socket: $!" unless $server_socket;

my $errmsg;
my $oneflg=1;
open(FILEHANDLE3,'>&',*STDERR) or die("error :$!");
while(1){
    open(STDERR,'>&',*FILEHANDLE3) or die("error :$!");
    if ($oneflg == 1) {
        print STDOUT "$port\n";
        $oneflg=0;
    }
    #print STDERR 'READY',"\n";
    $client_socket = $server_socket->accept;
    #print $client_socket encode_json ['ex',"echom 'socket accept'"],"\n";
    my $hersockaddr    = getpeername($client_socket);
    (my $clport, my $cliaddr) = sockaddr_in($hersockaddr);
    my $herhostname    = gethostbyaddr($cliaddr, AF_INET);
    my $herstraddr     = inet_ntoa($cliaddr);

    if ($herstraddr ne "127.0.0.1") {
        $client_socket->close;
        next;
    }

    my $data={};
    my $sig=0;
    while(my $msg = <$client_socket>){
        my $data_ref = decode_json($msg) or die "decode_json_error";
        $sig = @{$data_ref}[0];
        $data = @{$data_ref}[1];
        last;
    }
    if ($sig == 0) {
        next;
    }
    if(exists $data->{datasource}){
        disconnect();
        my $result={};
        $result->{status}=1;
        $datasource=$data->{datasource};
        $user=defined($data->{user})?$data->{user}:'';
        $pass=$data->{pass};
        $limitrows=$data->{limitrows};
        $dbencoding=$data->{encoding};
        $primarykeyflg=$data->{primarykeyflg};
        eval {
            $oracleflg = (${datasource} =~ /oracle:/i);
            $odbcflg = (${datasource} =~ /odbc:/i);
            $postgresflg = (${datasource} =~ /pg:/i);
            while (my ($key, $value) = each(%{$data->{envdict}})){
                $ENV{$key}=$value;
            }
            $dbh=DBI->connect("DBI:${datasource}",$user,$pass,
                {
                      pg_enable_utf8 => 1
                    , mysql_enable_utf8 => 1
                    , RootClass => "DBIxEncoding"
                    , encoding => $dbencoding }) or die DBI::errstr;
            $g_primary_key={};
        };
        if($@){
            my $message = Encode::is_utf8($@) ? $@ : Encode::decode($dbencoding,$@);
            outputlog("CONNECT ERROR:DBI:${datasource} ${user} ${pass}:" . $message,$port);
            $result->{status}=9;
        }else{
            outputlog("CONNECT:${datasource} ${user} $dbencoding",$port);
            $dbh->{AutoCommit} = 0;
            $dbh->{RaiseError} = 1;
        }
        $result->{user}=$user;
        #print $client_socket encode_json ['ex',"redraw"],"\n";
        #print $client_socket encode_json ['ex',"echom 'dbhconnect'"],"\n";
        print $client_socket encode_json [$sig,$result],"\n";
    } elsif(defined($dbh)) {
        #my $tempfile="${basedir}/" . $user . '_' . getdatetime . ".dat";
        my $tempfile=$data->{tempfile};
        open(STDERR,'>>',"${tempfile}.err") or die("error :$!");
        my $result = rutine($data,$sig,$tempfile);
        $result->{user}=$user;
        if(exists $data->{close}){
            disconnect();
            #print $client_socket encode_json ['ex',"redraw"],"\n";
            #print $client_socket encode_json ['ex',"echom 'dbhdisconnect'"],"\n";
            print $client_socket encode_json [$sig,$result],"\n";
        } else {
            #print $client_socket encode_json ['ex',"redraw"],"\n";
            #print $client_socket encode_json ['ex',"echom 'command done'"],"\n";
            print $client_socket encode_json [$sig,$result],"\n";
        }
        undef($result);
    } else {
        my $result={};
        $result->{status}=9;
        $result->{user}=$user;
        #print $client_socket encode_json ['ex',"redraw"],"\n";
        #print $client_socket encode_json ['ex',"echom 'dbhdisconnect'"],"\n";
        print $client_socket encode_json [$sig,$result],"\n";
    }
    undef($data);
}
sub rutine{
    my $data=shift;
    my $sig=shift;
    my $tempfile=shift;
    my $pid=$port;
    my $result={};
    $result->{status}=1;
    $result->{data}=$data;
    outputlog("INPUTDATA_KEYS:(${user})"  . join(",",keys(%{$data})) , $pid , $sig);
    eval {
        if(exists $data->{limitrows}){
            $limitrows=$data->{limitrows};
        }
        $result->{outputline}=[];
        if(exists $data->{rollback}){
            $dbh->rollback;
            $result->{rollback}=1;
        }elsif(exists $data->{setkey} && exists $data->{setvalue}){
            outputlog("DBH_KEYS:(${user})"  . join(",",keys(%{$dbh})) , $pid , $sig);
            $dbh->{$data->{setkey}}=$data->{setvalue};
        }elsif(exists $data->{commit}){
            $dbh->commit;
            $result->{commit}=1;
        }elsif(exists $data->{close}){
            $dbh->rollback;
            $result->{rollback}=1;
        }elsif(exists $data->{do}){
            my $start_time = Time::HiRes::time; 
            for my $sql (@{$data->{do}}){
                eval {
                    $dbh->func(1000000,'dbms_output_enable');
                };
                $sql =~ s/^[ \t\r\n]*$//m;
                next if $sql eq "";
                outputlog("UPDATE START(${user})"  . "\n" . $sql , $pid , $sig);
                $result->{lastsql} = $sql;
                $sth=$dbh->prepare($sql);
                my $rv=$sth->execute;
                $sth->finish;
                #my $rv=$dbh->do($sql);
                outputlog("UPDATE END COUNT($rv)" , $pid , $sig);
                my @outputline = ();
                push(@outputline,$rv . " updated.");
                eval {
                    foreach my $dog ($dbh->func('dbms_output_get')){
                        $dog = Encode::is_utf8($dog) ? $dog : Encode::decode($dbencoding, $dog);
                        if (defined($dog)) {
                            my @strlist = split(/\r\n|\r|\n/, $dog);
                            foreach my $str (@strlist){
                                push(@outputline,$str);
                                outputlog("DBMS_OUTPUT_LINE:" . $str , $pid , $sig);
                            }
                        }
                    }
                };
                push(@{$result->{outputline}},\@outputline);
                my $t_offset = int((Time::HiRes::time - $start_time)*1000);
                $result->{time}=${t_offset};
            }
        }else{
            $dbh->{LongTruncOk}=1;
            $dbh->{LongReadLen}=102400;
            my $username=$user eq '' ? undef : $user;
            if (!$oracleflg) {
                $username=undef;
            }
            if($data->{table_info} == 1){
                my $ltableNm=!defined($data->{table_name}) ? undef : $data->{table_name};
                my $ltabletype=!defined($data->{tabletype}) ? undef : $data->{tabletype};
                $ltableNm=!defined($ltableNm) || $ltableNm =~ /^\s*$/ ? undef : $ltableNm;
                $ltabletype=!defined($ltabletype) || $ltabletype =~ /^\s*$/ ? undef : $ltabletype;
                $sth=$dbh->table_info( undef, $username, $ltableNm, $ltabletype );
                exec_sql($data,$sig,$tempfile,$result,0);
            }elsif($data->{column_info} == 1){
                if(exists $g_primary_key->{$data->{tableNm}}){
                    $result->{primary_key}=$g_primary_key->{$data->{tableNm}};
                } else {
                    my @primary_key=$dbh->primary_key( undef, $username, $data->{tableNm});
                    $g_primary_key->{$data->{tableNm}} = \@primary_key;
                    $result->{primary_key}=\@primary_key;
                }
                if(exists $g_columns->{$data->{tableNm}}){
                    #select DATAFILE;
                    open(DATAFILE,'>>',$tempfile) or die("error :$!");
                    binmode DATAFILE,  (":encoding(" . $vimencoding . ')');
                    print DATAFILE $g_columns->{$data->{tableNm}}, "\n";
                    close(DATAFILE);
                    $result = $g_columns_result->{$data->{tableNm}};
                    $result->{data}=$data;
                } else {
                    $sth=$dbh->column_info( undef, $username, $data->{tableNm}, undef );
                    exec_sql($data,$sig,$tempfile,$result,0);
                }
            }elsif(exists $data->{sql}){
                eval {
                    $dbh->func(1000000,'dbms_output_enable');
                };
                my $sql = $data->{sql};
                $sql =~ s/^[ \t\r\n]*$//m;
                next if $sql eq "";
                outputlog("SELECT START(${user})" . "\n" . $sql , $pid , $sig);
                if ($primarykeyflg == 1) {
                    if(exists $g_primary_key->{$data->{tableNm}}){
                        $result->{primary_key}=$g_primary_key->{$data->{tableNm}};
                    } else {
                        my @primary_key=$dbh->primary_key( undef, $username, $data->{tableNm});
                        $g_primary_key->{$data->{tableNm}} = \@primary_key;
                        $result->{primary_key}=\@primary_key;
                    }
                }
                $result->{lastsql} = $sql;
                $sth=$dbh->prepare($sql);
                exec_sql($data,$sig,$tempfile,$result,1);
                my @outputline = ();
                eval {
                    foreach my $dog ($dbh->func('dbms_output_get')){
                        $dog = Encode::is_utf8($dog) ? $dog : Encode::decode($dbencoding, $dog);
                        if (defined($dog)) {
                            my @strlist = split(/\r\n|\r|\n/, $dog);
                            foreach my $str (@strlist){
                                push(@outputline,$str);
                                outputlog("DBMS_OUTPUT_LINE:" . $str , $pid , $sig);
                            }
                        }
                    }
                };
                push(@{$result->{outputline}},\@outputline);
            }
        }
    };
    if ($@) {
        my $message = Encode::is_utf8($@) ? $@ : Encode::decode($dbencoding, $@);
        outputlog($message , $pid , $sig);
        $message =~ s/ at ((?! at ).)*\Z//m;
        my @outputline = ();
        eval {
            foreach my $dog ($dbh->func('dbms_output_get')){
                $dog = Encode::is_utf8($dog) ? $dog : Encode::decode($dbencoding, $dog);
                if (defined($dog)) {
                    my @strlist = split(/\r\n|\r|\n/, $dog);
                    foreach my $str (@strlist){
                        push(@outputline,$str);
                        outputlog("DBMS_OUTPUT_LINE:" . $str , $pid , $sig);
                    }
                }
            }
        };
        $result->{status}=9;
        if(exists $data->{do}){
            for my $msg (split(/\r\n|\r|\n/, $message)){
                push(@outputline,$msg);
            }
        } else {
            open(DATAFILE,'>',$tempfile) or die("error :$!");
            binmode DATAFILE,  (":encoding(" . $vimencoding . ')');
            print DATAFILE $message;
            close(DATAFILE);
        }
        push(@{$result->{outputline}},\@outputline);
    } 
    return $result;
}

sub exec_sql{
    my $data=shift;
    my $sig=shift;
    my $tempfile=shift;
    my $result=shift;
    my $exeflg=shift;
    my $pid=$port;
    my $start_time = Time::HiRes::time; 
    if ($odbcflg && $exeflg == 0) {
    } else {
        $sth->execute;
    }
    #if($sth->rows > 0){
    #    $dbh->rollback;
    #    die "select only " . $sth->rows;
    #}
    if(!exists $sth->{NAME} || @{$sth->{NAME}}==0){
        die "select only ";
    }
    my $tableJoinNm=$data->{tableJoinNm};
    $result->{cols}=[];
    $result->{colsindex}=[];
    my $cols="";
    my $i=0;
    foreach my $col (@{$sth->{NAME}}){
        if ($data->{table_info} == 1 && ($col eq 'TABLE_CAT' || $col eq 'TABLE_SCHEM')) {
        }elsif ($data->{column_info} ==1 && ($col eq 'TABLE_CAT' || $col eq 'TABLE_SCHEM')) {
        } else {
            $col=Encode::is_utf8($col) ? $col : Encode::decode($dbencoding, $col);
            push(@{$result->{cols}},$col);
            push(@{$result->{colsindex}},$i);
            $cols = $cols . "\t" . $col;
        }
        $i=$i+1;
    }
    $cols =~ s/^\t//;
    if(@{$result->{cols}}){
        #select DATAFILE;
        open(DATAFILE,'>>',$tempfile) or die("error :$!");
        binmode DATAFILE,  (":encoding(" . $vimencoding . ')');
        print DATAFILE $tableJoinNm, "\n";
        print DATAFILE $cols, "\n";
    }
    my $cnt=1;
    my $cbrcnt=50000;
    my $brcnt=$cbrcnt;
    $result->{cnt}=0;
    while($brcnt >= $cbrcnt){
        $brcnt=1;
        my @list=();
        my $endflg=1;
        while(my @arr = $sth->fetchrow_array()){
            push @list,\@arr;
            last if $limitrows != -1 && $cnt++>=$limitrows;
            if ($brcnt++>=$cbrcnt) {
                $endflg=0;
                my $t_offset = int((Time::HiRes::time - $start_time)*1000);
                outputlog("SELECT WHILE: TIME(${t_offset}ms) COUNT(" . ($cnt-1) . ")" . " LIMITROWS($limitrows) " . $tempfile , $pid , $sig);
                last;
            }
        }
        #print "list Size : " . total_size(\$list) . "Byte\n";
        $result->{cnt}+=@list;
        if ($endflg==1) {
            my $t_offset = int((Time::HiRes::time - $start_time)*1000);
            $result->{time}=${t_offset};
            outputlog("SELECT END: TIME(${t_offset}ms) COUNT(" . ($cnt-1) . ")" . " LIMITROWS($limitrows) " . $tempfile , $pid , $sig);
        }
        #print Dumper $result;
        if(@{$result->{cols}}){
            my $rows="";
            for my $select (@list){
                my $record ="";
                for my $i (@{$result->{colsindex}}){
                    my $val = $select->[$i];
                    if(!defined($val)){
                        if (exists $data->{null}) {
                            $val = $data->{null};
                        } else {
                            $val = "";
                        }
                    }
                    if (exists $data->{linesep} && defined($data->{linesep}) && $val =~ /[\r\n]+/) {
                        outputlog('linesep:' . $data->{linesep} , $pid , $sig);
                        $val =~ s/[\r\n]+/$data->{linesep}/g;
                    }
                    if (exists $data->{surround} && defined($data->{surround}) && $data->{column_info} != 1 && $data->{table_info} != 1) {
                        $val = $data->{surround} . $val . $data->{surround};
                    }
                    $record = $record . "\t" . $val;
                }
                $record =~ s/^\t//;
                $rows .= ($record . "\n");
                undef($record);
                undef($select);
            }
            if($data->{column_info} == 1){
                $g_columns->{$data->{tableNm}} = ($tableJoinNm . "\n" . $cols . "\n" . $rows);
                $g_columns_result->{$data->{tableNm}} = $result;
            }
            print DATAFILE $rows;
            undef($rows);
        }
        undef(@list);
    }
    undef($cols);
    close(DATAFILE);
    $sth->finish;
}

exitfunc();
