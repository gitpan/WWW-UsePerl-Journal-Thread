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
		Test::More => 0,	# for testing
	}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT	=> 'Handles the retrieval of UsePerl journal comment threads.',
       AUTHOR	=> 'Barbie <modules@missbarbell.co.uk>') : ()),
);
