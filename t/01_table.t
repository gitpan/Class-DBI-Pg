use strict;
use Test::More tests => 8;

use DBI;

my $dbh;
my $database = $ENV{DB_NAME};
my $user     = $ENV{DB_USER};
my $password = $ENV{DB_PASS};

SKIP: {
    skip
      'You need to set the DB_NAME, DB_USER and DB_PASS environment variables',
      8
      unless ( $database && $user );
    my $dsn = "dbi:Pg:dbname=$database" if $database;
    $dbh = DBI->connect(
        $dsn, $user,
        $password,
        {
            AutoCommit => 1,
            PrintError => 0,
            RaiseError => 1,
        }
    );

    $dbh->do(<<'SQL');
CREATE TABLE class_dbi_pg1 (
    id SERIAL NOT NULL PRIMARY KEY,
    dat TEXT
)
SQL

    my $sth = $dbh->prepare(<<"SQL");
INSERT INTO class_dbi_pg1 (dat) VALUES(?)
SQL

    for my $dat (qw(foo bar baz)) {
        $sth->execute($dat);
    }
    $sth->finish;

    eval <<'' or die $@;
package Class::DBI::Pg::Test;
use base qw(Class::DBI::Pg);
__PACKAGE__->set_db( Main => $dsn, $user, $password );
__PACKAGE__->set_up_table('class_dbi_pg1');
1;

    is( Class::DBI::Pg::Test->retrieve_all, 3 );
    my $obj = Class::DBI::Pg::Test->retrieve(2);
    is( $obj->dat, 'bar' );
    my ($obj2) = Class::DBI::Pg::Test->search( dat => 'foo' );
    is( $obj2->id, 1 );

    like( Class::DBI::Pg::Test->sequence, qr/class_dbi_pg1_id_seq/ );
    my $new_obj = Class::DBI::Pg::Test->create( { dat => 'newone' } );
    is( $new_obj->id, 4 );

    eval <<'' or die $@;
package Class::DBI::Pg::Test2;
use base qw(Class::DBI::Pg);
__PACKAGE__->set_db( Main => $dsn, $user, $password );
__PACKAGE__->set_up_table('class_dbi_pg1', { ColumnGroup => 'Essential' });
1;

    $obj = Class::DBI::Pg::Test2->retrieve(2);
    is( $obj->dat, 'bar' );
    is_deeply( [ $obj->columns('Essential') ], [ qw(id dat) ] );

    $dbh->do(<<'SQL');
CREATE VIEW class_dbi_pg1_v AS SELECT * FROM class_dbi_pg1
SQL

    eval <<'' or die $@;
package Class::DBI::Pg::TestView;
use base qw(Class::DBI::Pg);
__PACKAGE__->set_db( Main => $dsn, $user, $password );
__PACKAGE__->set_up_table('class_dbi_pg1_v', { Primary => [ qw(id) ] });
1;

    $obj = Class::DBI::Pg::TestView->retrieve(2);
    is( $obj->dat, 'bar' );

    Class::DBI::Pg::Test->db_Main->disconnect;
    Class::DBI::Pg::Test2->db_Main->disconnect;
    Class::DBI::Pg::TestView->db_Main->disconnect;

}

END {
    if ($dbh) {
        eval {
            unless ( Class::DBI::Pg::Test->pg_version >= 7.3 )
            {
                $dbh->do('DROP SEQUENCE class_dbi_pg1_id_seq');
            }
            $dbh->do('DROP TABLE class_dbi_pg1 CASCADE');
        };
        $dbh->disconnect;
    }
}
