use Test;
use File::Spec;

BEGIN { plan tests => 2 }

local *A;
local *B;
local *C;

open A, File::Spec->catfile("t", "calltree.out") or ok(0), exit;
open B, File::Spec->catfile("t", "calltree_rf.out") or ok (0), exit;
open C, File::Spec->catfile("t", "calltree.ref") or ok(0), exit;

# by using default input record separator, perl will hopefully do the necessary
# newline translations on platforms not using "\012"
my @a = <A>;
my @b = <B>;
my @c = <C>;

ok(1) if join('', @a) eq join('', @c);
ok(1) if join('', @b) eq join('', @c); 
