use Test;
use File::Spec;

BEGIN { plan tests => 1 }

local *A;
local *B;

open A, File::Spec->catfile("t", "calltree.out") or ok(0), exit;
open B, File::Spec->catfile("t", "calltree.ref") or ok(0), exit;

# by using default input record separator, perl will hopefully do the necessary
# newline translations on platforms not using "\012"
my @a = <A>;
my @b = <B>;

ok(1) if join('', @a) eq join('', @b);
