#line 117
sub Devel::Calltree::print_report {
    my $calls = shift;
    for my $func (@$calls) {
	my $file = file($calls->{$func});
	if (funcs($calls->{ $func }) || !$OPT{-filter_empty}) {
	    print "\n$func  ($file): \n";
	    for my $target (funcs($calls->{$func})) {
		my $n = $target->name;
		my $l = $target->line;
		if ($target->is_method) {
                    print "  method   '$n'", ' ' x (60 - 14 - length($n)), " ($l)\n"; 
                    next;
                }
                print "  function '$n'", ' ' x (60 - 14 - length($n)), " ($l)\n";
            }
        }
    }
}

1;
