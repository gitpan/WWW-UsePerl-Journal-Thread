package WWW::UsePerl::Journal::Thread;

use vars qw($VERSION);
$VERSION = '0.01';

### CHANGES #########################################################
#   0.01   10/08/2003   Initial Release
#####################################################################

=head1 NAME

WWW::UsePerl::Journal::Thread - use.perl.org journal comment thread tool

=head1 SYNOPSIS

  use WWW::UsePerl::Journal;
  use WWW::UsePerl::Journal::Thread;

  my $journal = WWW::UsePerl::Journal->new('barbie');
  my @entries = $journal->entryids();

  my $thread = WWW::UsePerl::Journal::Thread->new(thread => $entries[0]);
  my @comments = $thread->commentids();
  foreach my $id (@comments) {
    printf "\n----\n%s [%d %s %d] %s",
	  $thread->comment($id)->subject(),
	  $thread->comment($id)->score(),
	  $thread->comment($id)->user(),
	  $thread->comment($id)->uid(),
	  $thread->comment($id)->date(),
	  $thread->comment($id)->content();
  }

  my $threadid = $thread->thread();

=head1 DESCRIPTION

Using WWW::UsePerl::Journal to extract entry ids, each id can be used to seed
a thread of comments. Each comment can be accessed as an object, thus values
can be retrieve for each object variable.

=cut

# -------------------------------------
# Library Modules

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common;
use Time::Piece;
use WWW::UsePerl::Journal::Comment;

# -------------------------------------
# Variables

use constant USEPERL => 'http://use.perl.org';

# -------------------------------------
# The Public Interface Subs

=head2 The Constructor

=head3 new()

  use WWW::UsePerl::Journal;
  my $journal = WWW::UsePerl::Journal->new('barbie');

  use WWW::UsePerl::Journal::Thread;
  my $j = WWW::UsePerl::Journal::Thread-E<gt>new(j => $journal, thread => 123456);

Creates an thread instance for the specified journal entry.

=cut

sub new {
    my $class = shift;
#    $class = ref($class) || $class;

    my %defaults = (
        j       => undef,
        thread  => undef,	# thread id
        entry	=> undef,	# entry id
    );
    my %opts = (@_);

    die "No parent object" 
	    unless exists $opts{j} and $opts{j}->isa('WWW::UsePerl::Journal');

    my $self = bless {%defaults, %opts}, $class;

    return $self;
}

=head2 thread

Returns the current thread id. 

=cut

sub thread {
    my $self = shift;
	$self->_commenthash	unless($self->{thread});
	return $self->{thread};
}

=head2 comment

Returns a comment object of the given comment ID

=cut

sub comment {
    my $self = shift;
    my $cid = shift;
	my %entries = $self->_commenthash;
    return $entries{$cid};
}

=head2 commentids

Returns an ascending array of the comment IDs. Can take an optional hash 
parameter containing {descending=>1} to return a descending array of the 
comment IDs, or {threaded=>1} to return a threaded list.

=cut

sub commentids {
    my $self = shift;
	my $hash = shift;
	my ($key,$sorter) = ('_commentids_asc',\&_ascender);

	($key,$sorter) = ('_commentids_dsc',\&_descender)	if(defined $hash && $hash->{descending});
	($key,$sorter) = ('_commentids_thd',sub{})			if(defined $hash && $hash->{threaded});

    $self->{$key} ||= do {
        my %entries = $self->_commenthash;
        my @IDs;

        foreach (sort $sorter keys %entries) {
            $IDs[$#IDs+1] = $_;
        }
        return @IDs;
    }
}

# -------------------------------------
# The Private Subs

# name: commenthash
# desc: Returns a hash of WWW::UsePerl::Journal::Comment objects

sub _commenthash {
    my $self = shift;
	my $url;

    return %{ $self->{_commenthash} }	if($self->{_commenthash});
	
	# URL depends upon which id we've been given, as thread and entry 
	# are different, but both can still return the thread list, just in
	# different formats

	if($self->{thread}) {
		$url = USEPERL . "/comments.pl?sid=" . $self->{thread};
	} elsif($self->{entry}) {
		my $user = $self->{j}->user;
		$url = USEPERL . "/~$user/journal/" . $self->{entry};
	}

#print STDERR "\n$url\n";
	my $content = $self->{j}->{ua}->request(GET $url)->content;
	die "could not create comment list" unless $content;

	my %comments;
	($self->{thread}) = ($content =~ m!sid=(\d+)!)	unless($self->{thread});

	# main comment thread
	while ( $content =~ m!
			<A\s+NAME="(\d+)">						# comment id
			<B>([^<]*)</B></A>						# subject
			\s*\(Score:(\d+),?\s?\w*\).*?			# score
			<A\s+HREF="//use.perl.org/~([^"]*)">.*?	# username
			\((\d+)\)</A>.*?						# userid
			on\s+([\d\s\.\:]+).*?					# date/time - on 2003.05.20 17:31
			comments.pl?.*?;cid=(\1)">				# back reference to contain the block
		!migxs ) {

		my ($cid,$subject,$score,$username,$uid,$date) = ($1,$2,$3,$4,$5,$6);
		my ($year, $month, $day, $hr, $mi) = $date =~ m!
		  (\d+)\.(\d+)\.(\d+)	  .*?	(\d+):(\d+)
		!smx;

		$date = Time::Piece->strptime(
			"$year $month $day ${hr}:$mi",
			'%Y %m %d %H:%M'
		);

		next unless defined $cid && $cid;
		$comments{$1} = WWW::UsePerl::Journal::Comment->new(
                j       => $self->{j},
                id      => $cid,
                subject => $subject,
                score   => $score,
                user    => $username,
                uid     => $uid,
                date    => $date,
                tid     => $self->{thread},
		);
	}

	# Note:
	# Due to the different formats the sub-comments can appear in,
	# we search for all PID strings first, then match each one against
	# the different formats.

	my @pids = ( $content =~ 
			m!
			(pid=\d+\#\d+)					# parent/comment id
			!migxs
		);

	foreach ( @pids ) {
		my ($pid,$cid) = (m!pid=(\d+)\#(\d+)!);

		my ($string,$format);
		my ($subject,$username,$score,$date) = ($content =~
				m!
				<BLOCKQUOTE><LI><A\s+HREF="//use.perl.org/comments.pl?.*?;
				pid=$pid\#$cid">					# parent/comment id
				(.*?)</A>.*?						# subject
				by\s+(.*?)\n.*?						# username
				\(Score:(\d+),?\s?\w*\).*?			# score
				>([\w\s\d,\@:]+[AP]M).*?			# date/time - Friday August 08, @01:51PM
				!migxs);

		if($date) {
			my ($dotw, $month, $day, $hr, $mi, $amp) = $date =~ 
				m!
					\w+ \s+ (\w+) \s+ (\d+),
					.*?
					(\d+):(\d+) \s+ ([AP]M)
				!smx;
			$hr += 12 if ($amp eq 'PM');
			$hr = 0 if $hr == 24;
#			$year = (localtime)[5];	# this is a guess hack due to this format not depicting the year

			$string = "$dotw $month $day ${hr}:$mi";
			$format = '%A %B %d %H:%M';

		} else {
			($subject,$username,$score,$date) = ($content =~
					m!
					<BLOCKQUOTE><LI><A\s+HREF="//use.perl.org/comments.pl?.*?;
					pid=$pid\#$cid">					# parent/comment id
					(.*?)</A>.*?						# subject
					by\s+(.*?)\n.*?						# username
					\(Score:(\d+),?\s?\w*\).*?			# score
					>([\d\s\.\:]+)</FONT>				# date/time - >2003.05.20 17:31</FONT>
					!migxs)	unless($date);

			my ($year, $month, $day, $hr, $mi) = $date =~ m!
			  (\d+)\.(\d+)\.(\d+)	  .*?	(\d+):(\d+)
			!smx;
			$string = "$year $month $day ${hr}:$mi";
			$format = '%Y %m %d %H:%M';
		}

		$date = Time::Piece->strptime($string,$format);


		next unless defined $cid;
		$comments{$cid} = WWW::UsePerl::Journal::Comment->new(
                j       => $self->{j},
				parent	=> $pid,
                id      => $cid,
                subject => $subject,
                user    => $username,
                score   => $score,
                date    => $date,
                tid     => $self->{thread},
		);
	}

	%{ $self->{_commenthash} } = %comments;
	return %{ $self->{_commenthash} };
}

# sort methods

sub _ascender { $a <=> $b }
sub _descender { $b <=> $a }

1;
__END__

=head1 BUGS & ENHANCEMENTS

No bugs reported as yet.

If you think you've found a bug, send details and
patches (if you have one) to E<lt>modules@missbarbell.co.ukE<gt>.

If you have a suggestion for an enhancement, though I can't promise to
implement it, please send details to E<lt>modules@missbarbell.co.ukE<gt>.

=head1 AUTHOR

Barbie, E<lt>barbie@missbarbell.co.ukE<gt>

for Miss Barbell Productions.

=head1 CREDITS

Russell Matbouli, for creating WWW::UsePerl::Journal in the first place 
and giving me the idea to extend it further.

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Barbie.

Distributed under GPL v2. See F<COPYING> included with this distibution.

=head1 SEE ALSO

L<perl>,
L<WWW::UsePerl::Journal>

F<http://use.perl.org/>

F<LWP>

=cut
