package WWW::UsePerl::Journal::Thread;

use vars qw($VERSION);
$VERSION = '0.08';

#----------------------------------------------------------------------------

=head1 NAME

WWW::UsePerl::Journal::Thread - Handles the retrieval of UsePerl journal comment threads.

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

A collection of routines to handle the retrieval of threads from a
UsePerl (L<http://use.perl.org/>) journal entry.

Using WWW::UsePerl::Journal, journal entry ids can be obtain. Each entry id
can be used to obtain a comment thread. Each comment property is accessed
via a comment object from within the thread.

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

=head1 METHODS

=over 4

=item new()

  use WWW::UsePerl::Journal;
  my $journal = WWW::UsePerl::Journal->new('barbie');

  use WWW::UsePerl::Journal::Thread;
  my $j = WWW::UsePerl::Journal::Thread-E<gt>new(j => $journal, entry => $entryid);

  use WWW::UsePerl::Journal::Thread;
  my $j = WWW::UsePerl::Journal::Thread-E<gt>new(j => $journal, thread => $threadid);

Creates an thread instance for the specified journal entry. Note that an entry ID
and thread ID are different numbers. An entry ID returned from $journal->entryids()
must use the entry => $entryid form to obtain the correct thread.

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

=item thread()

Returns the current thread id. 

=cut

sub thread {
    my $self = shift;
	$self->_commenthash	unless($self->{thread});
	return $self->{thread};
}

=item comment($commentid)

Returns a comment object of the given comment ID

=cut

sub comment {
    my $self = shift;
    my $cid = shift;
	my %entries = $self->_commenthash;
    return $entries{$cid};
}

=item commentids()

Returns an ascending array of the comment IDs.

Can take an optional hash containing; {descending=>1} to return a descending 
list of comment IDs, {ascending=>1} to return an ascending list or 
{threaded=>1} to return a thread ordered list. 'ascending' being the default.

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

#print STDERR "\n#url=[$url]\n";
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
#print STDERR "\n#atts=[$cid,$subject,$score,$username,$uid,$date]\n";
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
#print STDERR "\n#pid=[$pid], cid=[$cid]\n";
#print STDERR "\n#content=[$content]\n";

		my ($string,$format);
		my ($subject,$username,$score,$date) = ($content =~
				m!
				<BLOCKQUOTE><LI><A\s+HREF="//use.perl.org/comments.pl?.*?;
				pid=$pid\#$cid">					# parent/comment id
				(.*?)</A>.*?						# subject
				by\s+(.*?)\n.*?						# username
				\(Score:(\d+),?\s?\w*\)</FONT>\s+	# score
				<FONT[^>]+>(.*?)</FONT>				# date/time 
				!mixs);

#print STDERR "\n#fields=[$subject,$username,$score,$date]\n";

		if(my @re = $date =~ m!\w+\s+(\w+)\s+(\d+),.*?(\d+):(\d)\s+([AP]M)!s) {
			my ($dotw, $month, $day, $hr, $mi, $amp) = @re;
			$hr += 12 if ($amp eq 'PM');
			$hr = 0 if $hr == 24;
#			$year = (localtime)[5];	# this is a guess hack due to this format not depicting the year

#print STDERR "\n#date=[$date] [$dotw,$month,$day,$hr,$mi,$amp]\n";
			$string = "$dotw $month $day ${hr}:$mi";
			$format = '%A %B %d %H:%M';

		} else {
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

Russell Matbouli, for creating WWW::UsePerl::Journal in the first place 
and giving me the idea to extend it further.

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2003-2005 Barbie for Miss Barbell Productions
  All Rights Reserved.

  Distributed under GPL v2. See F<COPYING> included with this distibution.

=cut
