use Test;
use File::Spec;

# writing tests for a module running at CHECK-time is somewhat tricky
# this test-script always succeeds. It creates a calltree in a file
# and checks in 2.t that the file is identical to a reference calltree

BEGIN { 
    plan tests => 1;
    ok(1);
};
use Devel::Calltree -exclude	    => [ '.' ], 
                    -include	    => [ "Devel::Calltree" ],
                    -output	    => File::Spec->catfile("t", "calltree_rf.out"),
                    -test	    => 1,
		    -reportfuncs    => File::Spec->catfile("t", "report_funcs.pl");

