use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Devel::Calltree',
    VERSION_FROM      => 'lib/Devel/Calltree.pm', 
    PREREQ_PM         => {
                            'B::Utils' => 0,
    }, 
    EXE_FILES         => [ qw(script/calltree) ],
    ($] >= 5.005 ?     
      (ABSTRACT_FROM  => 'lib/Devel/Calltree.pm', 
       AUTHOR         => 'Tassilo von Parseval <tassilo.parseval@post.rwth-aachen.de>') : ()),
    clean             => { FILES => 't/calltree.out' },
);
