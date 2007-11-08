#!/usr/bin/perl

#use warnings;
#use strict;


# Note:
# All dates coming back from use.perl are stored locally and manipulated by
# Time::Piece. This module is influenced by the timezone. No timezone testing
# is done by this distribution, so all dates are validate to be within 24 hours
# of the expected date.


use lib './t';
use Test::More tests => 25;
use WWW::UsePerl::Journal;
use WWW::UsePerl::Journal::Thread;

my $username  = 'barbie';
my $entryid   = 13956;		# 
my $threadid  = 14740;		# these are for the same journal entry
my $commentid = 22842;      #

my $journal = WWW::UsePerl::Journal->new($username);
$journal->debug(1); # turn debugging on


##
## Tests based on a threadid
##

{
    my $thread = WWW::UsePerl::Journal::Thread->new(
                    thread	=> $threadid,
                    j		=> $journal,
    );

    isa_ok($journal,'WWW::UsePerl::Journal');
    isa_ok($thread,'WWW::UsePerl::Journal::Thread');

    is($thread->thread(),$threadid);

    my @cids = $thread->commentids();
    unless(@cids) {
        diag("\nurl=[http://use.perl.org/comments.pl?sid=$threadid]");
        diag($journal->log());
        $journal->log('clear'=>1);
    }

    SKIP: {
        skip 'Cannot access comments from thread',10 unless(@cids);

        cmp_ok(scalar(@cids) => 'gt' => 1);		# there's at least 3

        my $comment = $thread->comment($commentid);
        isa_ok($comment,'WWW::UsePerl::Journal::Comment');
        SKIP: {
            skip 'Cannot access comment in thread',8 unless(defined $comment);

            my %hash_is = (
                id		=> 22842,	
                subject	=> 'Locales',
                user	=> 'Dom2',
                uid		=> 2981,
            );

            my %hash_like = (
                content	=> qr|Turn them off now.*?<p>-Dom|,
                score	=> qr!\d+!,
            );

            foreach my $item (sort keys %hash_is) {
                my $value = $comment->$item();
                if(!is($value,$hash_is{$item},"... testing $item")) {
                    diag('error: '.$journal->error());
                    diag('log: '.$journal->log());
                    $journal->log('clear'=>1);
                }
            }
            foreach my $item (sort keys %hash_like) {
                my $value = $comment->$item();
                if(!like($value,$hash_like{$item},"... testing $item")) {
                    diag('error: '.$journal->error());
                    diag('log: '.$journal->log());
                    $journal->log('clear'=>1);
                }
            }

            my $s = $comment->date()->epoch;
            my $diff = abs($s - 1060186500);
            if($diff < 12 * 3600) {         # +/- 12 hours for a 24 hour period
                ok(1, "date check");
            } else {
                is $s => 1060186500, "date check";
            }

            my $text = "$comment";	# stringyfied version
            is($text,$comment->content());
        }
    }
}

$journal->log('clear' => 1);

##
## Tests based on a entryid
##

{
    my $thread = WWW::UsePerl::Journal::Thread->new(
                    entry	=> $entryid,
                    j		=> $journal,
    );

    isa_ok($thread,'WWW::UsePerl::Journal::Thread');

    @cids = $thread->commentids();
    unless(@cids) {
        diag("\nurl=[http://use.perl.org/~$username/journal/$entryid]");
        diag($journal->log());
        $journal->log('clear'=>1);
    }

    SKIP: {
        skip 'Cannot access comments from entry',11 unless(@cids);

        is((@cids > 2),1);		# there's at least 3

        is($thread->thread(),$threadid);

        $commentid = 22847;
        $comment = $thread->comment($commentid);
        isa_ok($comment,'WWW::UsePerl::Journal::Comment');

        %hash_is = (
            id		=> $commentid,	
            subject	=> 'Re:Locales',
            user	=> 'barbie',
            uid		=> 2653,
        );

        %hash_like = (
            content	=> qr|From the experience I\'ve just had that would be a good idea.|,
            score	=> qr!\d+!,
        );

        foreach my $item (sort keys %hash_is) {
            my $value = $comment->$item();
            is($value,$hash_is{$item},"... testing $item");
        }
        foreach my $item (sort keys %hash_like) {
            my $value = $comment->$item();
            like($value,$hash_like{$item},"... testing $item");
        }

        $s = $comment->date()->epoch;
        $diff = abs($s - 1060220100);
        if($diff < 12 * 3600) {         # +/- 12 hours for a 24 hour period
            ok(1, "date check");
        } else {
            is $s => 1060220100, "date check";
        }

        $text = "$comment";	# stringyfied version
        is($text,$comment->content());
    }
}
