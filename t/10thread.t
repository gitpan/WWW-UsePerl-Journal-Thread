#!/usr/bin/perl -w
use strict;

use lib './t';
use Test::More qw(no_plan);
use WWW::UsePerl::Journal;
use WWW::UsePerl::Journal::Thread;

my $username = 'barbie';
my $threadid = 14740;		# these are for the same
my $entryid = 13956;		# journal entry

my $journal = WWW::UsePerl::Journal->new($username);


##
## Tests based on a threadid
##

my $thread = WWW::UsePerl::Journal::Thread->new(
				thread	=> $threadid,
				j		=> $journal,
);

isa_ok($journal,'WWW::UsePerl::Journal');
isa_ok($thread,'WWW::UsePerl::Journal::Thread');

is($thread->thread(),$threadid);

my @cids = $thread->commentids();
is((@cids > 2),1);		# there's at least 3

my $comment = $thread->comment($cids[0]);
isa_ok($comment,'WWW::UsePerl::Journal::Comment');

# Barbie: 20/04/2004
# The date/time test has been removed as use.perl can report 2 different
# times for the same entry. Each time being an hour apart. For example
# the entry below can be reported as either of the two date/times below:
#	date	=> 'Wed Aug  6 15:15:00 2003',
#	date	=> 'Wed Aug  6 16:15:00 2003',
# No idea why and no idea how to fix it. May be a locale thing :(

my %hash = (
	content	=> q|Turn them off now.  They'll do you no good at all and they'll fuck up your ls output (Which eejit decicided to sort case insensitively with locales turned on?).<p>Oh, and they'll fuck your postgres databases too if you have one.  And probably more stuff I haven't discovered and never will because I TURNED THE FUCKERS OFF.<p>The only sane thing to do on a RedHat box is <tt>sudo rm -f<nobr> <wbr></nobr>/etc/sysconfig/i18n</tt>.  People who want locales can turn 'em on on a per user basis.<p>Keep looking at the quotes at the bottom  of each use.perl page.  There's a good one from Jarkko about locales.<p>-Dom|,
	id		=> 22842,	
	score	=> 3,
	subject	=> 'Locales',
	user	=> 'Dom2',
	uid		=> 2981,
);

foreach my $item (sort keys %hash) {
	my $value = eval "\$comment->$item()";
	is($value,$hash{$item});
}

my $text = "$comment";	# stringyfied version
is($text,$comment->content());


##
## Tests based on a entryid
##

$thread = WWW::UsePerl::Journal::Thread->new(
				entry	=> $entryid,
				j		=> $journal,
);

isa_ok($thread,'WWW::UsePerl::Journal::Thread');

@cids = $thread->commentids();
is((@cids > 2),1);		# there's at least 3

is($thread->thread(),$threadid);

$comment = $thread->comment($cids[1]);
isa_ok($comment,'WWW::UsePerl::Journal::Comment');

# Barbie: 20/04/2004
# The date/time test has been removed as use.perl can report 2 different
# times for the same entry. Each time being an hour apart. For example
# the entry below can be reported as either of the two date/times below:
#	date	=> 'Thu Aug  7 00:35:00 2003',
#	date	=> 'Thu Aug  7 01:35:00 2003',
# No idea why and no idea how to fix it. May be a locale thing :(

%hash = (
	content	=> q|From the experience I've just had that would be a good idea. Since installing RH9, not being able to install DateTime, which relies on Module::Build, has stopped me testing and releasing Calender::List. I had figured when the question came up on install, my language option would be for the system dictionary. Silly me. Deleting might be a good way to go.|,
	id		=> 22847,	
	score	=> 1,
	subject	=> 'Re:Locales',
	user	=> 'barbie',
	uid		=> 2653,
);

foreach my $item (sort keys %hash) {
	my $value = eval "\$comment->$item()";
#	print STDERR "\ntesting $item\n";
	is($value,$hash{$item},"testing $item");
}

$text = "$comment";	# stringyfied version
is($text,$comment->content());
