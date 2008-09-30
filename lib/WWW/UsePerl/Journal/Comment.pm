package WWW::UsePerl::Journal::Comment;

use strict;
use warnings;

use vars qw($VERSION $AUTOLOAD);
$VERSION = '0.12';

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
# Variables

my %months = (
	'January'   => 1,
	'February'  => 2,
	'March'     => 3,
	'April'     => 4,
	'May'       => 5,
	'June'      => 6,
	'July'      => 7,
	'August'    => 8,
	'September' => 9,
	'October'   => 10,
	'November'  => 11,
	'December'  => 12,
);

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
    return $self->content();
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

    if($self->{content}) {
        $self->{content} =~ s!(\s+<(?:p|br /)>)*$!!gi;	# remove trailing whitespace formatting
        $self->{content} =~ s!\s+(<(p|br /)>)!$1!gi;	# remove whitespace before whitespace formatting
        $self->{content} =~ s!(<(p|br /)>){2,}!<p>!gi;	# remove repeated whitespace formatting
    }

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

my %autosubs = map {$_ => 1} qw(id date subject user uid score content);

sub AUTOLOAD {
	no strict 'refs';
	my $name = $AUTOLOAD;
	$name =~ s/^.*:://;
	die "Unknown sub $AUTOLOAD\n"	unless($autosubs{$name});

	*$name = sub {
			my $self = shift;
			my $done = 1;
            $done = $self->_get_content()	unless($self->{$name});
            return  unless(defined $done);              # something went wrong
			return  unless(defined $self->{$name});     # couldn't resolve parameter
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

    return $self->{j}->error("No thread specified")	unless($thread);

    my $url = USEPERL . "/comments.pl?sid=$thread&cid=$ID";
    my $content = $self->{j}->{ua}->request(GET $url)->content;

    if($self->{j}->debug) {
        $self->{j}->log('mess' => "\n#_get_content: url=[$url]\n");
        $self->{j}->log('mess' => "\n#_get_content: content=[$content]\n");
    }

    return $self->{j}->error("Error getting entry") unless $content;
    return $self->{j}->error( "Comment $ID does not exist")
        if $content =~ m#Nothing for you to see here.  Please move along.#i;

    # remember there are different presentations for dates!!!!

	my ($string,$format);
	$content =~ s/\n//g;
	my @fields = ( $content =~ m!
            <li\s+id="tree_(\d+)"\s+class="comment[^"]*">    # comment id
    .*?     <h4><a[^>]+>([^<]+)</a>                             # subject
    .*?     <span\s+id="comment_score_\1"\s+class="score">
    .*?     Score:(\d+).*?</h4>                                 # score
	.*?		<a\s+href="//use.perl.org/~([^\"/]*)/?">        # username
	.*?		\((\d+)\)</a>?						            # userid
	.*?		on\s+([\w\d\s\@,.:]+)   					    # date/time - "2003.05.20 17:31" or "Friday August 08 2003, @01:51PM"
    .*?     <div\s+id="comment_body_\1">(.*?)</div>         # text
        !mixs );

    if($self->{j}->debug) {
        $self->{j}->log('mess' => "\n#_get_content: fields=[".(join("][",map {$_||''} @fields))."]\n");
    }

    return  unless(@fields);

	my ($year, $month, $day, $hr, $mi) = $fields[5] =~ m! (\d+)\.(\d+)\.(\d+) .*? (\d+):(\d+) !smx;
    unless($day) {
        my $amp;
    	($month, $day, $year, $hr, $mi, $amp) = $fields[5] =~ m! \w+\s+ (\w+) \s+(\d+)\s*(\d*), \s+ @(\d+):(\d+)([AP]M) !smx;
        $month = $months{$month};
    	$year = (localtime)[5]  unless($year);	# current year formatting drops the year.
        $hr += 12 if ($amp eq 'PM');
        $hr = 0 if $hr == 24;
    }

    if($self->{j}->debug) {
        $self->{j}->log('mess' => "\n#_get_content: date=[$year $month $day ${hr}:$mi]\n");
    }
	$self->{date} = Time::Piece->strptime( "$year $month $day ${hr}:$mi", '%Y %m %d %H:%M' );

	# just in case we overwrite good stuff
	$self->{subject}	= $fields[1]	unless($self->{subject});
	$self->{score}		= $fields[2]	unless($self->{score});
	$self->{user}		= $fields[3]	unless($self->{user});
	$self->{uid}		= $fields[4]	unless($self->{uid});
	$self->{content}	= $fields[6]	unless($self->{content});

	return 1  unless($self->{content});				# What no content!

	$self->{content} =~ s!(\s+<(?:p|br /)>)*$!!gi;	# remove trailing whitespace formatting
	$self->{content} =~ s!\s+(<(p|br /)>)!$1!gi;	# remove whitespace before whitespace formatting
	$self->{content} =~ s!(<(p|br /)>){2,}!<p>!gi;	# remove repeated whitespace formatting

    return 1;
}

sub DESTROY {}

1;

__END__

=back

=head1 SUPPORT

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties that are not explained within the POD
documentation, please submit a bug to the RT system (see link below). However,
it would help greatly if you are able to pinpoint problems or even supply a
patch.

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me by sending an email
to barbie@cpan.org .

RT: L<http://rt.cpan.org/Public/Dist/Display.html?Name=WWW-UsePerl-Journal-Thread>

=head1 SEE ALSO

L<WWW::UsePerl::Journal>,
L<LWP>

F<http://use.perl.org/>

=head1 CREDITS

Russell Matbouli, for creating L<WWW::UsePerl::Journal> in the first place
and giving me the idea to extend it further.

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  for Miss Barbell Productions <http://www.missbarbell.co.uk>.

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2003-2007 Barbie for Miss Barbell Productions.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

The full text of the licenses can be found in the F<Artistic> and
F<COPYING> files included with this module, or in L<perlartistic> and
L<perlgpl> in Perl 5.8.1 or later.

=cut
