use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'WWW::UsePerl::Journal::Thread',
    'VERSION_FROM'	=> 'lib/WWW/UsePerl/Journal/Thread.pm', # finds $VERSION
    'PREREQ_PM'		=> {
		WWW::UsePerl::Journal => 0.11,
		LWP::UserAgent => 0,
		HTTP::Request::Common => 0,
		Time::Piece => 0,
	}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/WWW/UsePerl/Journal/Thread.pm', # retrieve abstract from module
       AUTHOR     => 'Barbie <modules@missbarbell.co.uk>') : ()),
    'LIBS'		=> [''], # e.g., '-lm'
    'DEFINE'		=> '', # e.g., '-DHAVE_SOMETHING'
	# Insert -I. if you add *.h files later:
    'INC'		=> '', # e.g., '-I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # 'OBJECT'		=> '$(O_FILES)', # link all the C files too
);
