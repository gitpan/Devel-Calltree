package Devel::Calltree;

use 5.006;
use strict;

use vars qw($VERSION);
use B::Utils; 

$VERSION = '0.00_2';

my %OPT;
my $CURFILE;

sub import {
    my $class = shift;
    %OPT = @_;
    push @{ $OPT{-exclude} }, __PACKAGE__;
    if (my $h = $OPT{-output}) {
        if (ref($h) eq 'GLOB') {
            select $h;
        } else {
            open FH, ">$h" or die "Could not open $h for output: $!";
            select FH;
        }
    }
    # when -test is set, we are running the tests.
    # in order to get consistent output, $CURFILE will
    # be tied so that it always return 'XXX'.
    tie $CURFILE => "Devel::Calltree::testmode" if $OPT{-test};
}

sub INIT {

    my %root = B::Utils::all_roots();
    remove_excluded(\%root);
    my @pkgs = get_packages(\%root);

    my %CALLS;
    while (my ($name, $root) = each %root) {
        my ($pkg) = $name =~ /(.*)::/; 
        my @CALLS;
        
        # we pass the current package name ($pkg) 
        # so that we can find the real
        # package of $pkg::func in find_subcall().
        B::Utils::walkoptree_simple($root, \&find_subcall, [\@CALLS, $pkg]);
        $CALLS{ $name } = bless [] => $CURFILE;
        for my $call (@CALLS) {
            push @{ $CALLS{$name} }, $call;
        }
    }
    my $calls = bless \%CALLS => __PACKAGE__;
    if (!$OPT{-iscalled}) {
        $calls->print_report;
    } else {
        $calls->print_report_called;
    }
    exit;
}

sub find_subcall {
    my ($op, $args) = @_;
    
    my ($data, $name) = @$args;
    
    $CURFILE = $B::Utils::file;

    # function call
    if ($op->name eq 'gv' && $op->next && $op->next->name eq 'entersub') {
        my $realfnc;
        my $fnc = join '::', $op->gv->STASH->NAME, $op->gv->NAME;
        
        # do we need to attempt resolving the real function name?
        # this assumes that a call to a fully qualified function
        # can be taken as is (unless it is main::func()).
        if ($op->gv->STASH->NAME eq $name or $op->gv->STASH->NAME eq 'main') { 
            no strict 'refs';
            # not sure why this happens:
            # sometimes B::svref_2object(...)->STASH returns a B::SPECIAL
            # which has no NAME() method
            my $pkg = eval { B::svref_2object(\&$fnc)->STASH->NAME };
            $pkg ||= '??';
            $fnc =~ s/.*:://;
            $realfnc = "${pkg}::$fnc";
        } else {
            $realfnc = $fnc;
        }
        $B::Utils::file =~ tr#/##s; # squeeze: blib/lib//bla.pm => blib/lib/bla.pm
        push @$data, bless { name       => $realfnc, 
                             line       => $B::Utils::line, 
                             file       => $B::Utils::file,
                             is_method  => 0 } => 'Devel::Calltree::Func';
        return;
    }
    
    # method call
    if ($op->name eq 'method_named' && $op->next && $op->next->name eq 'entersub') {
        push @$data, bless { name       => $op->gv->PV,
                             line       => $B::Utils::line,
                             file       => $B::Utils::file,
                             is_method  => 1 } => 'Devel::Calltree::Func';
    }

}

sub print_report {
    my $calls = shift;
    # the outer map() will turn __MAIN__ into 'z' x 100 in the hope
    # that this will put '__MAIN__' at the end of the list
    for my $caller (map $_->[0],
                    sort { $a->[1] cmp $b->[1] or $a->[2] cmp $b->[2] }
                    map [ $_, $_ ne '__MAIN__' ? /(.+)::(.+)/ : 'z' x 100 ], keys %$calls) {
        my $file = ref $calls->{ $caller };
        $file =~ tr#/##s; # squeeze: blib/lib//bla.pm => blib/lib/bla.pm
        if (@{$calls->{$caller}} || !$OPT{-filter_empty} ) {
            print "\n$caller  ($file): \n";
            for my $targ (sort { $a->line <=> $b->line } @{$calls->{$caller} || []}) {
                my $n = $targ->name;
                my $l = $targ->line;
                if ($targ->is_method) {
                    print "  method   '$n'", ' ' x (60 - 14 - length($n)), " ($l)\n"; 
                    next;
                }
                print "  function '$n'", ' ' x (60 - 14 - length($n)), " ($l)\n";
            }
        }
    }
}

sub print_report_called {
    
    my $calls = shift;
    my @funcs = @{ $OPT{ -iscalled } };
    my %notfound;
    @notfound{ @funcs } = ();
    my $pat = "(" . $funcs[0] . ")"; 
    $pat .= "|($_)" for @funcs[1..$#funcs];
    my @found;
    
    while (my ($caller, $candid) = each %$calls) {
        for (@$candid) {
            if ($_->name =~ /$pat/o) {
                delete $notfound{ $funcs[$+] };
                push @found, [ $caller, $_ ];
            }
        }
    } 
    if (keys %notfound) {
        print "These patterns did not match any called function:\n";
        print "  $_\n" for keys %notfound;
        print "\n";
    }

    print "These functions were called:\n";
    for (sort { $a->[1]->name cmp $b->[1]->name } @found) {
        printf "  %-8s %-30s from %-30s at line %i\n", $_->[1]->is_method ? "method" : "function", 
               $_->[1]->name, $_->[0], $_->[1]->line;
    }
}
        
        
sub remove_excluded {
    my $roots = shift;
    my @bad;
    my $patbad = join "|^", @{ $OPT{-exclude} };
    # no include pattern: come up with one that always fails
    my $patgood = join "|^", @{ $OPT{-include} || [ qw/&!%"§@@/ ]}; 
    $patbad = qr/^$patbad/;
    $patgood = qr/^$patgood/;
    
    for (keys %$roots) {
        push @bad, $_ if /$patbad/o && !/$patgood/o;
    }
    delete @$roots{ @bad };
}
   
sub get_packages {
   my $roots = shift;
   my %pkgs = map { /(.+)::/ ? $1 : __MAIN__ => 1 } keys %$roots;
   keys %pkgs;
}
   
sub array_to_hash {
    my @array = @_;
    my %hash;
    @hash{ @array } = (1) x @array;
    return %hash;
}

sub sort {
    my $self = shift;
    $self->{ "sorted\0" } = [       # prevent clash with function name 
        map $_->[0],
        sort { $a->[1] cmp $b->[1] or $a->[2] cmp $b->[2] }
        map [ $_, $_ ne '__MAIN__' ? /(.+)::(.+)/ : 'z' x 100 ], keys %$self ];
}
    
sub Devel::Calltree::Func::file         { shift->{ file } }
sub Devel::Calltree::Func::line         { shift->{ line } }
sub Devel::Calltree::Func::name         { shift->{ name } }
sub Devel::Calltree::Func::is_method    { shift->{ is_method } }


sub Devel::Calltree::testmode::TIESCALAR { bless \my $var => "Devel::Calltree::testmode" }
sub Devel::Calltree::testmode::FETCH     { "XXX" }
sub Devel::Calltree::testmode::STORE     { }

1;
__END__

=head1 NAME

Devel::Calltree - Create a report on which function/method called which.

=head1 SYNOPSIS

    perl -M"Devel::Calltree %OPTIONS" -e '<SCRIPT>'

    perl -M"Devel::Calltree %OPTIONS" script.pl

    perl -MDevel::Calltree -MModule::To::Inspect -e1

    # preferably you should be using the supplied script

    calltree [ OPTIONS ] -e '<SCRIPT>'

    calltree [ OPTIONS ] script.pl

    calltree [ OPTIONS ] -MModule::To::Inspect -e1

=head1 ABSTRACT

    Report who called whom.
    
=head1 DESCRIPTION

This module inspects the OP-tree of a program or module after compilation is
done and creates a report showing which method and function has been called by
whom.

Most of the time you want to use the F<calltree> utility instead. 

=head1 LIMITATIONS

This module is not as useful as it could be with respect to method-calls. While
the real package a called function resides in can be figured out in 99% of the
cases, this is not true for methods. Method dispatch happens at runtime and
therefore, there is no chance to find out whether 'Foo::method' or
'Bar::method' has been called in a case such as

    $obj->method;   # $obj either a 'Foo' or 'Bar' instance

Currently, it only reports the name of the method that has been called. If the method
has no proper name as in

    $obj->$method;

nothing is reported. This case is simply not detected.

=head1 TODO

Despite the above, handling of methods could be improved. Information deducible from the OP-tree
include:

    Class->method;      # even resolving inheritence when @ISA is known at CHECK-time
    $lexical->method;
    $PKG::VAR->method;
    $obj->method1->method2;
    func()->method;

=head1 BUGS

Assume many. Almost everything in this module is fragile at the moment.

=head1 SEE ALSO

L<calltree>

Also see the original posting to comp.lang.perl.misc that resulted in this module
at E<lt>http://groups.google.de/groups?hl=de&lr=&ie=UTF-8&selm=buuc15%24o3f%241%40plover.comE<gt>.

=head1 AUTHOR

Original idea and code by Mark Jason Dominus E<lt>mjd@plover.comE<gt>.

Current maintainer Tassilo von Parseval E<lt>tassilo.parseval@post.rwth-aachen.deE<gt>.

=head1 COPYRIGHT AND LICENSE

Original code copyright (C) 2003 Mark Jason Dominus

Revisions copyright (C) 2004 by Tassilo von Parseval

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
Copyright (C) 2004 by Tassilo von Parseval

=cut
