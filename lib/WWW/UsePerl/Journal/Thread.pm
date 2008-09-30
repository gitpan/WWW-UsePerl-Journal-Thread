package WWW::UsePerl::Journal::Thread;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.12';

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

use LWP::UserAgent;
use HTTP::Request::Common;
use Time::Piece;
use WWW::UsePerl::Journal::Comment;

# -------------------------------------
# Variables

use constant USEPERL => 'http://use.perl.org';

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
        debug   => 0
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
    my $cid  = shift;
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
	   ($key,$sorter) = ('_commentids_thd',sub{-1})			if(defined $hash && $hash->{threaded});

    $self->{$key} ||= do {
        my %entries = $self->_commenthash;
        my @IDs;

        $IDs[$#IDs+1] = $_  for(sort $sorter keys %entries);
        \@IDs;
    };

    return @{$self->{$key}};
}

# -------------------------------------
# The Private Methods

# name: commenthash
# desc: Returns a hash of WWW::UsePerl::Journal::Comment objects

sub _commenthash {
    my $self = shift;
	my $url = USEPERL;

    return %{ $self->{_commenthash} }	if($self->{_commenthash});

	# URL depends upon which id we've been given, as thread and entry
	# are different, but both can still return the thread list, just in
	# different formats

	if($self->{thread}) {
		$url .= "/comments.pl?sid=" . $self->{thread};
	} elsif($self->{entry}) {
		my $user = $self->{j}->user;
		$url .= "/~$user/journal/" . $self->{entry};
	} else {
        return; # nothing to get a handle on!
    }

	my $content = $self->{j}->{ua}->request(GET $url)->content;
	return $self->{j}->error("could not create comment list") unless $content;

    if($self->{j}->debug) {
        $self->{j}->log('mess' => "\n#_commenthash: url=[$url]\n");
        $self->{j}->log('mess' => "\n#_commenthash: content=[$content]\n");
    }

	my %comments;
	($self->{thread}) = ($content =~ m!sid=(\d+)!)	unless($self->{thread});

	# main comment thread
    my @queries = $content =~ m! href="//use.perl.org/comments.pl\?(.*?)" !sixg;
    for my $query (@queries) {

        my (@fields) = ($query =~ /sid=(\d+).*?pid=(\d+)(?:\#(\d+))?/);
           (@fields) = ($query =~ /sid=(\d+).*?cid=(\d+)/)  unless(@fields);

        my $cid = $fields[2] ? $fields[2] : $fields[1];
        my $pid = $fields[2] ? $fields[1] : undef;
        if($self->{j}->debug) {
            $self->{j}->log('mess' => "\n#_commenthash: cid=[".($cid||'undef')."], pid=[".($pid||'undef')."]\n");
        }

		next if(!$cid || defined $comments{$cid});
		$comments{$cid} = WWW::UsePerl::Journal::Comment->new(
                j       => $self->{j},
                id      => $cid,
                tid     => $self->{thread},
                parent  => $pid
		);
	}

	%{ $self->{_commenthash} } = %comments;
	return %{ $self->{_commenthash} };
}

# sort methods

sub _ascender  { $a <=> $b }
sub _descender { $b <=> $a }

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

=head1 AUTHOR

Barbie, E<lt>barbie@cpan.orgE<gt>
for Miss Barbell Productions L<http://www.missbarbell.co.uk>.

=head1 CREDITS

Russell Matbouli, for creating WWW::UsePerl::Journal in the first place
and giving me the idea to extend it further.

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2003-2005 Barbie for Miss Barbell Productions

  Distributed under GPL v2. See F<COPYING> included with this distibution.

=cut
