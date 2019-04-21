#
# Server side script
#
use strict;
use warnings;
use utf8;
use POSIX 'strftime';
use File::Basename;
use Carp ();
use Encode;
use Encode::Guess;
use IO::Handle;
use IO::Socket;
use JSON;
use DBI;
use List::Util;
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

my $g_client_socket;
my $g_dbh;
my $g_sth;
my $g_server_socket;
my $g_datasource;
my $g_user="";
my $g_pass;
my $g_limitrows;
my $g_oracleflg;
my $g_odbcflg;
my $g_postgresflg;
my $g_dbencoding;
my $g_primarykeyflg;
my $g_schema_list;
my $g_port=shift;
my $g_basedir=shift;
my $g_vimencoding=shift;
my $g_debuglog=shift;
my $g_cancelFlg = 0;

sub outputlog{
    if (!$g_debuglog) {
        return;
    }
    my $msg=shift;
    my $port=shift;
    my $process_id = 'PID:' . $$;
    my $date=strftime("%c",localtime(time));
    if(defined($port)){
        $port=" PORT:" . $port;
    }else{
        $port="";
    }
    print LOGFILE $date . $port . " " . $process_id . " " . $msg . "\n";
}

sub getdate{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon += 1;
    return sprintf("%04d%02d%02d",$year,$mon,$mday);
}
sub getdatetime{
    return strftime("%c",localtime(time));
}
sub disconnect{
    if(defined($g_dbh)){
        eval {
            $g_dbh->rollback;
            $g_dbh->disconnect;
            undef($g_dbh);
            outputlog("DISCONNECT",$g_port);
        };
    }
}
sub exitfunc{
    disconnect();
    if(defined($g_client_socket)){
        $g_client_socket->close;
    }
    if(defined($g_server_socket)){
        $g_server_socket->close;
    }
    outputlog("FINISHED" , $g_port);
    close(LOGFILE);
    close(LOCKFILE);
    unlink "${g_basedir}/${g_port}.lock";
}
sub exitfunc2{
    exitfunc();
    exit(0);
}
sub cancel{
    $g_cancelFlg = 1;
    if(defined($g_sth)){
        if ($g_sth->cancel) {
            outputlog("CANCEL",$g_port);
        } else {
            outputlog("CANCEL(finish)",$g_port);
            $g_sth->finish;
        }
    }
}
sub ulength{
    my $val=shift;
    my $size=0;
    for my $c (split(/(?=.)/,$val)){
        if (bytes::length $c > 1) {
            $size+=2;
        } elsif ($c =~ /[[:cntrl:]]/) {
            $size+=2;
        } else {
            $size+=1;
        }
    }
    return $size;
}
$SIG{HUP} = $SIG{TERM} = $SIG{KILL} = $SIG{QUIT} =\&exitfunc2;
$SIG{INT} = \&cancel;

binmode STDIN,  (":encoding(" . $g_vimencoding . ')');
binmode STDOUT,  (":encoding(" . $g_vimencoding . ')');
STDERR->autoflush;
STDOUT->autoflush;
LOGFILE->autoflush;
LOCKFILE->autoflush;

eval {
    if (-e $g_basedir) {
    } else {
        mkpath([$g_basedir]) or warn $!;
    }
};
if ($@) {
  die $@;
}
if ($g_debuglog) {
    open(LOGFILE,'>>',"${g_basedir}/socket_" . getdate . ".log") or die("error :$!");
    binmode LOGFILE,  (":encoding(" . $g_vimencoding . ')');
}
open(LOCKFILE,'>>',"${g_basedir}/${g_port}.lock") or die("error :$!");
$g_server_socket = IO::Socket::INET->new(
    LocalPort => $g_port, 
    Proto     => 'tcp', 
    Listen    => SOMAXCONN,
    ReuseAddr => 1,     
) or die $!;

Carp::croak "Could not create socket: $!" unless $g_server_socket;

my $errmsg;
my $oneflg=1;
my $exitflg=0;
open(FILEHANDLE3,'>&',*STDERR) or die("error :$!");
while(1){
    open(STDERR,'>&',*FILEHANDLE3) or die("error :$!");
    if ($oneflg == 1) {
        print STDOUT "$g_port\n";
        $oneflg=0;
    }
    if ($exitflg == 1) {
        last;
    }
    #print STDERR 'READY',"\n";
    outputlog("READY",$g_port);
    $g_client_socket = $g_server_socket->accept;
    outputlog("PROC START",$g_port);
    $g_cancelFlg = 0;
    #print $g_client_socket encode_json ['ex',"echom 'socket accept'"],"\n";
    my $hersockaddr    = getpeername($g_client_socket);
    (my $clport, my $cliaddr) = sockaddr_in($hersockaddr);
    my $herhostname    = gethostbyaddr($cliaddr, AF_INET);
    my $herstraddr     = inet_ntoa($cliaddr);

    if ($herstraddr ne "127.0.0.1") {
        $g_client_socket->close;
        next;
    }

    my $data={};
    my $sig=-1;
    while(my $msg = <$g_client_socket>){
        my $data_ref = decode_json($msg) or die "decode_json_error";
        $sig = @{$data_ref}[0];
        $data = @{$data_ref}[1];
        last;
    }
    if ($sig == -1) {
        outputlog("PROC END ${sig}",$g_port);
        next;
    }
    my $result={};
    $result->{status}=1;
    if(exists $data->{kill}){
        $exitflg=1;
        outputlog("KILL PROC" , $g_port);
        print $g_client_socket encode_json [$sig,$result],"\n";
        next;
    }
    if(exists $data->{delimiter}){
        $data->{delimiter} =~ s/\r\n|\r|\n/\n/g;
    }
    if(exists $data->{datasource}){
        disconnect();
        $result->{status}=1;
        $g_datasource=$data->{datasource};
        $g_user=defined($data->{user})?$data->{user}:'';
        $g_pass=$data->{pass};
        $g_limitrows=$data->{limitrows};
        $g_dbencoding=$data->{encoding};
        $g_primarykeyflg=$data->{primarykeyflg};
        $g_schema_list=$data->{schema_list};
        eval {
            $g_oracleflg = (${g_datasource} =~ /oracle:/i);
            $g_odbcflg = (${g_datasource} =~ /odbc:/i);
            $g_postgresflg = (${g_datasource} =~ /pg:/i);
            while (my ($key, $value) = each(%{$data->{envdict}})){
                $ENV{$key}=$value;
            }
            $g_dbh=DBI->connect("DBI:${g_datasource}",$g_user,$g_pass,
                {
                      pg_enable_utf8 => 1
                    , mysql_enable_utf8 => 1
                    , RootClass => "DBIxEncoding"
                    , encoding => $g_dbencoding }) or die DBI::errstr;
        };
        if($@){
            my $message = Encode::is_utf8($@) ? $@ : Encode::decode($g_dbencoding,$@);
            outputlog("CONNECT ERROR:DBI:${g_datasource} ${g_user} ${g_pass}:" . $message,$g_port);
            $result->{status}=9;
            $result->{message}=$message;
        }else{
            outputlog("CONNECT:${g_datasource} ${g_user} $g_dbencoding",$g_port);
            $g_dbh->{AutoCommit} = 0;
            $g_dbh->{RaiseError} = 1;
        }
        #$result->{user}=$g_user;
        #print $g_client_socket encode_json ['ex',"redraw"],"\n";
        #print $g_client_socket encode_json ['ex',"echom 'dbhconnect'"],"\n";
        print $g_client_socket encode_json [$sig,$result],"\n";
    } elsif(defined($g_dbh)) {
        #my $tempfile="${g_basedir}/" . $g_user . '_' . getdatetime . ".dat";
        my $tempfile=$data->{tempfile};
        #$result->{user}=$g_user;
        my $result={};
        if (exists $data->{close}){
            disconnect();
            #print $g_client_socket encode_json ['ex',"redraw"],"\n";
            #print $g_client_socket encode_json ['ex',"echom 'dbhdisconnect'"],"\n";
            print $g_client_socket encode_json [$sig,$result],"\n";
        } else {
            open(STDERR,'>>',"${tempfile}.err") or die("error :$!");
            $result = rutine($data,$sig,$tempfile);
            #print $g_client_socket encode_json ['ex',"redraw"],"\n";
            #print $g_client_socket encode_json ['ex',"echom 'command done'"],"\n";
            print $g_client_socket encode_json [$sig,$result],"\n";
            close(STDERR);
        }
        if (defined($tempfile) && -e "${tempfile}.err" && -z "${tempfile}.err") {
            unlink "${tempfile}.err";
        }
        if (defined($tempfile) && -e "${tempfile}" && -z "${tempfile}") {
            unlink "${tempfile}";
        }
    } else {
        my $result={};
        $result->{status}=9;
        #$result->{user}=$g_user;
        #print $g_client_socket encode_json ['ex',"redraw"],"\n";
        #print $g_client_socket encode_json ['ex',"echom 'dbhdisconnect'"],"\n";
        print $g_client_socket encode_json [$sig,$result],"\n";
    }
    undef($data);
    outputlog("PROC END" , $g_port);
}
sub rutine{
    my $data=shift;
    my $sig=shift;
    my $tempfile=shift;
    my $result={};
    $result->{status}=1;
    $result->{startdate}=getdatetime;
    $result->{data}=$data;
    outputlog("INPUTDATA_KEYS:(${g_user}) "  . join(",",keys(%{$data})) , $g_port);
    open(DATAFILE,'>>',$tempfile) or die("error :$!");
    binmode DATAFILE,  (":encoding(" . $g_vimencoding . ')');
    my @outputline = ();
    eval {
        my $start_time = Time::HiRes::time; 
        if(exists $data->{limitrows}){
            $g_limitrows=$data->{limitrows};
        }
        if(exists $data->{rollback}){
            $g_dbh->rollback;
            $result->{rollback}=1;
        }elsif(exists $data->{setkey} && exists $data->{setvalue}){
            outputlog("DBH_KEYS:(${g_user})"  . join(",",keys(%{$g_dbh})) , $g_port);
            $g_dbh->{$data->{setkey}}=$data->{setvalue};
        }elsif(exists $data->{commit}){
            $g_dbh->commit;
            $result->{commit}=1;
        }elsif(exists $data->{close}){
            $g_dbh->rollback;
            $result->{rollback}=1;
        }elsif(exists $data->{do}){
            my $continue = 0;
            if(exists $data->{continue}){
                $continue = $data->{continue}; 
            }
            for my $sql (@{$data->{do}}){
                my $loopstart_date = getdatetime; 
                my $loopstart_time = Time::HiRes::time; 
                eval {
                    $g_dbh->func(1000000,'dbms_output_enable');
                };
                $sql =~ s/\r\n|\r|\n/\n/gm;
                my $lsql = $sql;
                $lsql =~ s/(\t|\r\n|\r|\n)+/ /gm;
                $lsql =~ s/^ +//m;
                next if $lsql eq "";
                outputlog("UPDATE START(${g_user})"  . "\n" . $sql , $g_port);
                $g_sth=$g_dbh->prepare($sql);
                my $rv=-1;
                eval {
                    $rv=$g_sth->execute;
                    $g_sth->finish;
                };
                if ($continue == 0 && $@) {
                    die($@);
                }
                #my $rv=$g_dbh->do($sql);
                outputlog("UPDATE END COUNT($rv)" , $g_port);
                push(@outputline,$loopstart_date . '(' . int((Time::HiRes::time - $loopstart_time)*1000) . 'ms) ' . $rv . ' updated. "' . $lsql . '"');
                eval {
                    foreach my $dog ($g_dbh->func('dbms_output_get')){
                        $dog = Encode::is_utf8($dog) ? $dog : Encode::decode($g_dbencoding, $dog);
                        if (defined($dog)) {
                            my @strlist = split(/\r\n|\r|\n/, $dog);
                            foreach my $str (@strlist){
                                push(@outputline,'DBMS_OUTPUT_GET:' . $str);
                                outputlog("DBMS_OUTPUT_LINE:" . $str , $g_port);
                            }
                        }
                    }
                };
                my $t_offset = int((Time::HiRes::time - $start_time)*1000);
                $result->{time}=${t_offset};
            }
        }else{
            $g_dbh->{LongTruncOk}=1;
            $g_dbh->{LongReadLen}=102400;
            my $user=$g_user eq '' ? undef : $g_user;
            if (!$g_oracleflg) {
                $user=undef;
            }
            if(exists $data->{sql} && $data->{sql} ne ''){
                my $loopstart_date = getdatetime; 
                my $loopstart_time = Time::HiRes::time; 
                eval {
                    $g_dbh->func(1000000,'dbms_output_enable');
                };
                my $sql = $data->{sql};
                $sql =~ s/\r\n|\r|\n/\n/gm;
                my $lsql = $sql;
                $lsql =~ s/(\t|\r\n|\r|\n)+/ /gm;
                $lsql =~ s/^ +//m;
                next if $lsql eq "";
                my $schem = $data->{schem} == '' ? $user : $data->{schem};
                my @schema_list = ($schem);
                push(@schema_list, @{$g_schema_list});
                foreach my $schem2 (@schema_list){
                    outputlog('primary_key schem2:' . $schem2 , $g_port);
                    if ($g_primarykeyflg == 1) {
                        my @primary_key = ();
                        @primary_key=$g_dbh->primary_key( undef, $schem2, $data->{tableNm});
                        if ($#primary_key > 0) {
                            outputlog('PRIMARY_KEY:' . @primary_key , $g_port);
                            $result->{primary_key}=\@primary_key;
                            last;
                        }
                    }
                }
                $g_sth=$g_dbh->prepare($sql);
                outputlog("EXEC SQL START " . substr($lsql,0,100), $g_port);
                exec_sql($data,$sig,$tempfile,$result,1);
                if ($result->{status} == 2) {
                    push(@outputline,$loopstart_date . '(' . int((Time::HiRes::time - $loopstart_time)*1000) . 'ms) ' . $result->{cnt} . ' updated. "' . $lsql . '"');
                }

                eval {
                    foreach my $dog ($g_dbh->func('dbms_output_get')){
                        $dog = Encode::is_utf8($dog) ? $dog : Encode::decode($g_dbencoding, $dog);
                        if (defined($dog)) {
                            my @strlist = split(/\r\n|\r|\n/, $dog);
                            foreach my $str (@strlist){
                                push(@outputline,'DBMS_OUTPUT_GET:' . $str);
                                outputlog("DBMS_OUTPUT_LINE:" . $str , $g_port);
                            }
                        }
                    }
                };
                my $t_offset = int((Time::HiRes::time - $start_time)*1000);
                $result->{time}=${t_offset};
                if ($result->{status} == 1) {
                    my $schem = $data->{schem} == '' ? $user : $data->{schem};
                    my @schema_list = ($schem);
                    push(@schema_list, @{$g_schema_list});
                    foreach my $schem2 (@schema_list){
                        $g_sth=$g_dbh->table_info( undef, $schem2, $data->{tableNm}, undef );
                        $result->{table_info}=$g_sth->fetchall_arrayref({});
                        $g_sth->finish();
                        outputlog('column_info schem2:' . $schem2 , $g_port);
                        $g_sth=$g_dbh->column_info( undef, $schem2, $data->{tableNm}, undef );
                        $result->{column_info}=$g_sth->fetchall_arrayref({});
                        $g_sth->finish();
                        if ($#{$result->{column_info}} > 0) {
                            last;
                        }
                    }
                }
            } elsif($data->{table_info} == 1){
                my $ltableNm=!defined($data->{table_name}) ? undef : $data->{table_name};
                my $ltabletype=!defined($data->{tabletype}) ? undef : $data->{tabletype};
                $ltableNm=!defined($ltableNm) || $ltableNm =~ /^\s*$/ ? undef : $ltableNm;
                $ltabletype=!defined($ltabletype) || $ltabletype =~ /^\s*$/ ? undef : $ltabletype;
                $g_sth=$g_dbh->table_info( undef, $user, $ltableNm, $ltabletype );
                outputlog("EXEC TABLE_INFO START ", $g_port);
                exec_sql($data,$sig,$tempfile,$result,0);
            }elsif($data->{column_info} == 1){
                my $schem = $data->{schem} == '' ? $user : $data->{schem};
                outputlog('tableNm:' . $data->{tableNm} , $g_port);
                outputlog('schem:' . $schem , $g_port);
                my @schema_list = ($schem);
                push(@schema_list, @{$g_schema_list});
                foreach my $schem2 (@schema_list){
                    outputlog('primary_key schem2:' . $schem2 , $g_port);
                    my @primary_key = ();
                    @primary_key=$g_dbh->primary_key( undef, $schem2, $data->{tableNm});
                    if ($#primary_key > 0) {
                        outputlog('PRIMARY_KEY:' . @primary_key , $g_port);
                        $result->{primary_key}=\@primary_key;
                        last;
                    }
                }
                foreach my $schem2 (@schema_list){
                    outputlog('column_info schem2:' . $schem2 , $g_port);
                    $g_sth=$g_dbh->column_info( undef, $schem2, $data->{tableNm}, undef );
                    outputlog("EXEC COLUMN_INFO START ", $g_port);
                    exec_sql($data,$sig,$tempfile,$result,0);
                    if ($result->{cnt} > 0) {
                        last;
                    }
                }
            }

        }
    };
    if ($@) {
        my $message = Encode::is_utf8($@) ? $@ : Encode::decode($g_dbencoding, $@);
        outputlog($message , $g_port);
        $message =~ s/ at ((?! at ).)*\Z//m;
        push(@outputline,$message);
        eval {
            foreach my $dog ($g_dbh->func('dbms_output_get')){
                $dog = Encode::is_utf8($dog) ? $dog : Encode::decode($g_dbencoding, $dog);
                if (defined($dog)) {
                    my @strlist = split(/\r\n|\r|\n/, $dog);
                    foreach my $str (@strlist){
                        push(@outputline,'DBMS_OUTPUT_GET:' . $str);
                        outputlog("DBMS_OUTPUT_LINE:" . $str , $g_port);
                    }
                }
            }
        };
        $result->{status}=9;
    }
    print DATAFILE join("\n",@outputline);

    close(DATAFILE);
    return $result;
}

sub exec_sql{
    my $data=shift;
    my $sig=shift;
    my $tempfile=shift;
    my $result=shift;
    my $exeflg=shift;
    my $start_time = Time::HiRes::time; 
    if ($g_odbcflg && $exeflg == 0) {
    } else {
        $g_sth->execute;
    }
    if ($g_cancelFlg == 1) {
        cancel();
    }
    outputlog("FETCH START" , $g_port);
    $result->{startfetch}=getdatetime;
    if(!exists $g_sth->{NAME} || @{$g_sth->{NAME}}==0){
        $result->{status}=2;
        $result->{cnt}=$g_sth->rows;
        return;
    }
    my $tableJoinNm=$data->{tableJoinNm};
    my $i=0;
    $result->{cols}=[];
    $result->{maxcols}=[];
    $result->{colsindex}=[];
    foreach my $col (@{$g_sth->{NAME}}){

        #if ($data->{table_info} == 1 && ($col ne 'TABLE_NAME' && $col ne 'TABLE_TYPE' && $col ne 'REMARKS')) {
        #}elsif ($data->{column_info} ==1 && ($col eq 'TABLE_CAT' || $col eq 'TABLE_SCHEM')) {
        #} else {
        $col=Encode::is_utf8($col) ? $col : Encode::decode($g_dbencoding, $col);
        push(@{$result->{cols}},$col);
        push(@{$result->{colsindex}},$i);
        push(@{$result->{maxcols}},ulength($col));
        #}
        $i=$i+1;
    }
    my $firstIdx=@{$result->{colsindex}}[0];
    my $cnt=1;
    my $cbrcnt=50000;
    my $brcnt=$cbrcnt;
    $result->{cnt}=0;
    while($brcnt >= $cbrcnt){
        $brcnt=1;
        my @list=();
        while(my @arr = $g_sth->fetchrow_array()){
            push @list,\@arr;
            last if $g_limitrows != -1 && $cnt++>=$g_limitrows;
            if ($brcnt++>=$cbrcnt) {
                my $t_offset = int((Time::HiRes::time - $start_time)*1000);
                outputlog("EXEC WHILE: TIME(${t_offset}ms) COUNT(" . ($cnt-1) . ")" . " LIMITROWS($g_limitrows) " . $tempfile , $g_port);
                last;
            }
        }
        #print "list Size : " . total_size(\$list) . "Byte\n";
        $result->{cnt}+=@list;
        #print Dumper $result;
        if(@{$result->{cols}}){
            my $rows="";
            for my $select (@list){
                my $record ="";
                for my $i (@{$result->{colsindex}}){
                    my $val = $select->[$i];
                    my $maxsize = 0;
                    if(!defined($val)){
                        if (exists $data->{null}) {
                            $val = $data->{null};
                        } else {
                            $val = "";
                        }
                    }
                    $val =~ s/\t/    /gm;
                    if (exists $data->{linesep} && defined($data->{linesep}) && $val =~ /(\r\n|\r|\n)+/) {
                        $val =~ s/(\r\n|\r|\n)+/$data->{linesep}/g;
                    }
                    if (!(exists $data->{linesep} && defined($data->{linesep})) && $val =~ /(\r\n|\r|\n)+/){
                        my $surr = '"';
                        if (exists $data->{surround} && defined($data->{surround})) {
                            $surr = $data->{surround};
                        }
                        my @linesVal = map({ulength $_;} split(/(\r\n|\r|\n)+/, ($surr . $val . $surr)));
                        $maxsize = List::Util::max(@linesVal);
                        $val =~ s/(\r\n|\r|\n)/\n/g;
                        $val =  $data->{prelinesep} . $surr . $val . $surr . $data->{prelinesep};
                    } elsif (exists $data->{surround} && defined($data->{surround}) && $data->{column_info} != 1 && $data->{table_info} != 1) {
                        my $surr = $data->{surround};
                        $val =  $surr . $val . $surr;
                    }

                    if($maxsize == 0){
                        $maxsize = ulength($val);
                    }
                    
                    if (@{$result->{maxcols}}[$i - $firstIdx] < $maxsize) {
                        @{$result->{maxcols}}[$i - $firstIdx] = $maxsize;
                    }

                    $record = $record . "\t" . $val;
                }
                $record =~ s/^\t//;
                $rows .= ($record . "\n");
                undef($record);
                undef($select);
            }
            print DATAFILE $rows;
            undef($rows);
        }
        undef(@list);
    }
    $g_sth->finish;
    outputlog("FETCH END" , $g_port);
    my $t_offset = int((Time::HiRes::time - $start_time)*1000);
    outputlog("EXEC END: TIME(${t_offset}ms) COUNT(" . ($cnt-1) . ")" . " LIMITROWS($g_limitrows) " . $tempfile , $g_port);
}

exitfunc();
