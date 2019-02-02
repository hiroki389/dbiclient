use strict;
use warnings;
use Carp;

###
# DBIxEncoding
#
package DBIxEncoding;
use base qw(DBI);

###
# DBIxEncoding::db
#
package DBIxEncoding::db;
use base qw(DBI::db);

sub debuglog {
    if (1==0) {
        open(LOGFILE,'>>','test.log') or die("error :$!");
        print LOGFILE join('',@_) . "\n";
        close LOGFILE;
    }
}

sub connected {
    my ($self, $dsn, $user, $credential, $attrs) = @_;
    $self->{private_dbix_encoding} = { 'encoding' => $attrs->{encoding} || 'utf8' };
    debuglog("connected:encoding:" . $self->{private_dbix_encoding}->{encoding});
}

sub prepare {
    my ($self, @args) = @_;
    my $sth = $self->SUPER::prepare(@args) or return;
    $sth->{private_dbix_encoding} = $self->{private_dbix_encoding};
    
    return $sth;
}

sub do {
    my ($self, $stmt, $attr, @args) = @_;
    return $self->SUPER::do($stmt, $attr, @args);
}
sub primary_key {
    my ($self, @args) = @_;
    return $self->SUPER::primary_key(@args);
}

sub primary_key_info {
    my ($self, @args) = @_;
    my $sth = $self->SUPER::primary_key_info(@args) or return;
    $sth->{private_dbix_encoding} = $self->{private_dbix_encoding};
    return $sth;
}

sub table_info {
    my ($self, @args) = @_;
    my $sth = $self->SUPER::table_info(@args) or return;
    $sth->{private_dbix_encoding} = $self->{private_dbix_encoding};
    return $sth;
}

sub column_info {
    my ($self, @args) = @_;
    my $sth = $self->SUPER::column_info(@args) or return;
    $sth->{private_dbix_encoding} = $self->{private_dbix_encoding};
    return $sth;
}

###
# DBIxEncoding::st
#
package DBIxEncoding::st;
use base qw(DBI::st);

use Encode;

sub debuglog {
    if (1==0) {
        open(LOGFILE,'>>','test.log') or die("error :$!");
        print LOGFILE join('',@_) . "\n";
        close LOGFILE;
    }
}

sub bind_param {
    my ($self, @args) = @_;
    return $self->SUPER::bind_param(@args);
}

sub execute {
    my ($self, @args) = @_;
    return $self->SUPER::execute(@args);
}

sub fetch {
    my ($self, @args) = @_;
    my $encoding = $self->{private_dbix_encoding}->{encoding};
    #debuglog("fetch:encoding:" . $encoding);
    
    my $row = $self->SUPER::fetch(@args) or return;
    
    for my $val (@$row) {
        $val = Encode::is_utf8($val) ? $val : Encode::decode($encoding, $val);
    }
    
    return $row;
}

sub fetchrow_array {
    my $self = shift;
    my $encoding = $self->{private_dbix_encoding}->{encoding};
    #debuglog("fetchrow_array:encoding:" . $encoding);
    
    my @array = $self->SUPER::fetchrow_array or return;
    
    return map { Encode::is_utf8($_) ? $_ : Encode::decode($encoding, $_) } @array;
}

sub fetchall_arrayref {
    my ($self, $slice, $max_rows) = @_;
    my $encoding = $self->{private_dbix_encoding}->{encoding};
    #debuglog("fetchall_arrayref:encoding:" . $encoding);
    
    my $array_ref;
    
    if ($slice) {
        $array_ref = $self->SUPER::fetchall_arrayref($slice, $max_rows) or return;
    }
    else {
        $array_ref = $self->SUPER::fetchall_arrayref or return;
        for my $array (@{ $array_ref }) {
            @{ $array } = map { Encode::is_utf8($_) ? $_ : Encode::decode($encoding, $_) } @{ $array };
        }
    }
    
    return $array_ref;
}


1;
__END__
