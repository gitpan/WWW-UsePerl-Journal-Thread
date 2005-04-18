package WWW::UsePerl::Journal::Comment;

use strict;
use warnings;

use vars qw($VERSION $AUTOLOAD);
$VERSION = '0.08';

#----------------------------------------------------------------------------

=head1 NAME

WWW::UsePerl::Journal::Comment - Handles the retrieval of UsePerl journal entry comments.

=head1 SYNOPSIS

  $comments{$1} = WWW::UsePerl::Journal::Comment->new(
      j       => $self,
      id      => $1,
      subject => $2,
      score   => $3,
      user    => $4,
      uid     => $5,
      date    => $6,
      tid     => $thread,
  );

  $comments{$1}->subject();

  # called from WWW::UsePerl::Journal object
  $self->comment($1)->content();

=head1 DESCRIPTION

A collection of routines to handle the retrieval of comments from a
UsePerl (L<http://use.perl.org/>) journal entry.

=cut

# -------------------------------------
# Library Modules

use LWP::UserAgent;
use HTTP::Request::Common;
use Time::Piece;
use WWW::UsePerl::Journal;

use constant USEPERL => 'http://use.perl.org';
use overload q{""}  => sub { $_[0]->stringify() };

# -------------------------------------
# The Public Interface Subs

=head1 METHODS

=over 4

=item stringify - For String Context

When an object is called directly, stringification occurs. Safer to
use -E<gt>content instead.

=cut

sub stringify {
    my $self = shift;
    $self->content();
}

=item new()

Each comment is retrieved as an object. Note that the parent object 
(from WWW::UsePerl::Journal), thread id and comment id are mandatory 
requirements to create the object.

=cut

sub new {
    my $class = shift;
    $class = ref($class) || $class;

    my %defaults = (
        j       => undef,
        id      => undef,	# comment id
		parent	=> undef,	# parent comment id (threads)
        tid     => undef,	# thread id

        uid     => undef,	# poster id
        user    => undef,	# poster name
        subject => undef,	# the title of the comment
        content => undef,	# ... content by any chance?
        date    => undef,	# date comment posted
        score   => undef,	# comment score
    );
    my %opts = (@_);

    die "No parent object" 
	    unless exists $opts{j} and $opts{j}->isa('WWW::UsePerl::Journal');

    my $self = bless {%defaults, %opts}, $class;

    return $self;
}

=item The Accessors

The following accessor methods are available:

  id  
  date  
  subject  
  user
  uid
  score
  content

All functions can be called to return the current value of the associated
object variable.

=cut

my @autosubs = qw(
	id	date	subject	user	uid	score	content
);
my %autosubs = map {$_ => 1} @autosubs;

sub AUTOLOAD {
	no strict 'refs';
	my $name = $AUTOLOAD;
	$name =~ s/^.*:://;
	die "Unknown sub $AUTOLOAD\n"	unless($autosubs{$name});
	
	*$name = sub {
			my $self = shift;
			$self->_get_content()	unless($self->{$name});
			return unless($self->{$name});
			$self->{$name} =~ s/^\s+//;					# remove leading whitespace
			$self->{$name} =~ s/\s+$//;					# remove trailing whitespace
			return $self->{$name};
	};
	goto &$name;
}

# -------------------------------------
# The Private Subs

# name:	_get_content
# args:	self .... object itself
# retv: content text
# desc: Retrieves the content and additional information for a given
#       comment. Splits the fields into object variables and returns
#       the content text

sub _get_content {
    my $self    = shift;
    my $ID      = $self->{id};
    my $thread  = $self->{tid};

    die "No thread specified\n"	unless($thread);

#print STDERR USEPERL . "/comments.pl?sid=$thread&cid=$ID\n";
    my $content = $self->{j}->{ua}->request(
        GET USEPERL . "/comments.pl?sid=$thread&cid=$ID")->content;
    die "Error getting entry\n" unless $content;
    die "Comment $ID does not exist\n" 
        if $content =~ m#Nothing for you to see here.  Please move along.#i;


	# remember there are different presentations for dates!!!!

	my ($string,$format);
	$content =~ s/\n//g;
	my @fields = ( $content =~ 
		m!
			<A\s+NAME="(\d+)">						# comment id
			<B>([^<]*)</B></A>						# subject
			\s*\(Score:(\d+),?\s?\w*\).*?			# score
			<A\s+HREF="//use.perl.org/~([^"]*)">.*?	# username
			\((\d+)\)</A>.*?						# userid
			on\s+([\d\s\.\:]+).*?					# date/time - 2003.05.20 17:31
            comments.pl?.*?;cid=\1">.*?				# back reference to contain the block
			<TABLE.*?><TR.*?><TD.*?>(.*?)\s*</TD></TR></TABLE>
        !mixs );

	if(@fields) {
		my ($year, $month, $day, $hr, $mi) = $fields[5] =~ m!
		  (\d+)\.(\d+)\.(\d+)	  .*?	(\d+):(\d+)
		!smx;
		$string = "$year $month $day ${hr}:$mi";
		$format = '%Y %m %d %H:%M';

	} else {

		@fields = ( $content =~ 
			m!
				<A\s+NAME="(\d+)">						# comment id
				<B>([^<]*)</B></A>						# subject
				\s*\(Score:(\d+),?\s?\w*\).*?			# score
				<A\s+HREF="//use.perl.org/~([^"]*)">.*?	# username
				\((\d+)\)</A>.*?						# userid
				on\s+([\w\s\d,\@:]+[AP]M).*?			# date/time - Friday August 08, @01:51PM
				comments.pl?.*?;cid=\1">.*?				# back reference to contain the block
				<TABLE.*?><TR.*?><TD.*?>(.*?)\s*</TD></TR></TABLE>
			!mixs );

		my ($dotw, $month, $day, $hr, $mi, $amp) = $fields[5] =~ 
			m!
				\w+ \s+ (\w+) \s+ (\d+),
				.*?
				(\d+):(\d+) \s+ ([AP]M)
			!smx;
		$hr += 12 if ($amp eq 'PM');
		$hr = 0 if $hr == 24;
#		$year = (localtime)[5];	# this is a guess hack due to this format not depicting the year

		$string = "$dotw $month $day ${hr}:$mi";
		$format = '%A %B %d %H:%M';
	}

	$fields[5] = Time::Piece->strptime($string,$format);

	# just in case we overwrite good stuff
	$self->{subject}	= $fields[1]	unless($self->{subject});
	$self->{score}		= $fields[2]	unless($self->{score});
	$self->{user}		= $fields[3]	unless($self->{user});
	$self->{uid}		= $fields[4]	unless($self->{uid});
	$self->{date}		= $fields[5]	unless($self->{date});
	$self->{content}	= $fields[6]	unless($self->{content});

	return	unless($self->{content});				# What no content!

	$self->{content} =~ s/(\s+<(?:P|BR)>)*$//gi;	# remove trailing whitespace formatting
	$self->{content} =~ s/\s+(<(P|BR)>)/$1/gi;		# remove whitespace before whitespace formatting
	$self->{content} =~ s/(<(P|BR)>){2,}/<P>/gi;	# remove repeated whitespace formatting
}

sub DESTROY {}

1;

__END__

=back

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties, that is not explained within the POD
documentation, please send an email to barbie@cpan.org or submit a bug to the
RT system (http://rt.cpan.org/). However, it would help greatly if you are 
able to pinpoint problems or even supply a patch. 

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 SEE ALSO

L<WWW::UsePerl::Journal>,
L<LWP>

F<http://use.perl.org/>

=head1 AUTHOR

Barbie, E<lt>barbie@cpan.orgE<gt>
for Miss Barbell Productions L<http://www.missbarbell.co.uk>.

=head1 CREDITS

Russell Matbouli, for creating L<WWW::UsePerl::Journal> in the first place 
and giving me the idea to extend it further.

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2003-2005 Barbie for Miss Barbell Productions
  All Rights Reserved.

  Distributed under GPL v2. See F<COPYING> included with this distibution.

=cut

