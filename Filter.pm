package Chess::PGN::Filter;

use 5.006;
use strict;
use warnings;
use Chess::PGN::Parse;
use Chess::PGN::EPD;
use Text::DelimMatch;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
    &filter	
);
our $VERSION = '0.04';


sub filter {
    my %parameters = @_;
    if ($parameters{'filtertype'} eq 'XML') {
        filterXML(@_);
    }
    elsif ($parameters{'filtertype'} eq 'TEXT') {
        filterTEXT(@_);
    }
    else {
    	die "Unknown filtertype: '$parameters{'filtertype'}' not supported.\n";
    }
}

sub filterTEXT {
    my %parameters = @_;
    my $file = $parameters{'source'} or die "Missing source parameter: $!\n";
    my $substitutions = $parameters{'substitute'}; 
    my ($comments,$ravs,$nags,$ECO,$NIC,$Opening) = ('no','no','no','yes','no','yes');
    $comments = lc($parameters{'comments'}) if exists($parameters{'comments'});
    $ravs = lc($parameters{'ravs'}) if exists($parameters{'ravs'});
    $nags = lc($parameters{'nags'}) if exists($parameters{'nags'});
    $ECO = lc($parameters{'ECO'}) if exists($parameters{'ECO'});
    $NIC = lc($parameters{'NIC'}) if exists($parameters{'NIC'});
    $Opening = lc($parameters{'Opening'}) if exists($parameters{'Opening'});
    my $pgn = new Chess::PGN::Parse($file) or die "Can't open $file: $!\n";
    my $games_ref = $pgn->read_all({save_comments => 'yes'});
    my $arrayref;
    my @moves;
    my %comments;
    my %tags;
    my %ravs;
    my %nags;
    my $result;
    my $date;
    my @date;
    my @epd;

    foreach  (@{$games_ref}) {
        my $movetext;
        my $move = 1;
        my $termination;
        my $n = 1;
        my $white;
        my $ckey;

        $arrayref = $_;
        @moves = ();
        %comments = ();
        %tags = ();
        %nags = ();
        %ravs = ();
        foreach my $key  (keys %{$arrayref}) {
            my $ref = %{$arrayref}->{$key};
            if (ref($ref)) {
                if ($key eq 'GameMoves') {
                    @moves = @{$ref};
                }
                elsif ($key eq 'GameComments') {
                    %comments = %{$ref};
                    foreach  (keys %comments) {
                        my $t = $comments{$_};
                        my $NAG;
                        my $RAV;
                        my $COMMENT;

                        ($t,$RAV) = deLIMIT($t,'\(','\)');
                        ($t,$COMMENT) = deLIMIT($t,'\{','\}');
                        ($t,$NAG) = deLIMIT($t,'\$','\D');
                        if ($RAV) {
                            $ravs{$_} = $RAV;
                        }
                        if ($NAG ne '') {
                            $nags{$_} = $NAG;
                        }
                        if ($COMMENT) {
                            $comments{$_} = $COMMENT;
                        }
                        else {
                        	delete($comments{$_});
                        }
                   }
                }
            }
            elsif ($ref) {
                if ($key ne 'Game') {
                    $tags{$key} = $ref;
                }
            }
        }
        if (exists($tags{'ECO'})) {
            my $tax = $tags{'ECO'};

            if ($tax eq '?' or $tax eq '') {
                $tags{'ECO'} = epdcode('ECO',\@epd)
            }
        }
        else {
            $tags{'ECO'} = epdcode('ECO',\@epd) if $ECO;
        }
        if (exists($tags{'NIC'})) {
            my $tax = $tags{'NIC'};

            if ($tax eq '?' or $tax eq '') {
                $tags{'NIC'} = epdcode('NIC',\@epd)
            }
        }
        else {
            $tags{'NIC'} = epdcode('NIC',\@epd) if $NIC;
        }
        if (exists($tags{'Opening'})) {
            my $tax = $tags{'Opening'};

            if ($tax eq '?' or $tax eq '') {
                $tags{'Opening'} = epdcode('Opening',\@epd);
            }
        }
        else {
            $tags{'Opening'} = epdcode('Opening',\@epd) if $Opening;
        }
        $termination =  ($tags{'Result'} =~ /^1-0|0-1|1\/2-1\/2|\*$/ ? $tags{'Result'} : '*');
        foreach  ('Event','Site','Date','Round','White','Black','Result') {
            if ($substitutions) {
                while (my ($one,$another) = each(%{$substitutions})) {
                    if ($tags{$_} =~ /$one/) {
                        $tags{$_} =~ s/$one/$another/;
                    }
                }
            }
            print "[",$_," \"$tags{$_}\"]\n";
            delete($tags{$_});
        }
        foreach  (sort keys %tags) {
            print "[",$_," \"$tags{$_}\"]\n";
        }
        print "\n";
        foreach (@moves) {
            $_ =~ s/0/O/g;
            if ($n % 2) {
                $ckey = "${move}w";
                $movetext .= "$move. ";
            }
            else {
                $ckey = "${move}b";
                $move++;
            }
            $movetext .= "$_ ";
            if (%comments and exists($comments{$ckey})) {
                my $s = $comments{$ckey};

                $movetext .= '(' . $s . ')' if ($comments eq 'yes');;
            }
            if (%nags and exists($nags{$ckey})) {
                my $s = $nags{$ckey};
                if ($s) {
                    if ($s < 6) {
                        chop($movetext);
                        $movetext .= NAG($s) . ' ';
                    }
                    else {
                        $movetext .= '{' . $s . '}' if ($nags eq 'yes');
                    }
                }                
            }
            if (%ravs and exists($ravs{$ckey})) {
                my $s = $ravs{$ckey};
                
                $movetext .= '[' . $s . ']' if ($ravs eq 'yes');;
            }
            $n++;
        }
        print join("\n",paragraph($movetext . $termination,78)),"\n\n";
        $movetext = '';
    }
}

sub paragraph {
    my $s = shift;
    my $n = shift;
    my $m = $n;

    while ($m < length($s)) {
        while(substr($s,$m,1) ne ' ') {
            $m--;
        }
        if (substr($s,$m - 1,1) eq '.') {
            $m--;
            next;
        }
        substr($s,$m,1) = '|';
        $m += $n;
    }
    return split(/\|/,$s);
}

sub filterXML {
    my %parameters = @_;
    my $file = $parameters{'source'} or die "Missing source parameter: $!\n";
    my ($fen,$position,$type,$border,$corner,$legend,$size,$font) = ('no','yes','marroquin','single','square','no','5','Chess Kingdom');
    $fen = lc($parameters{'fen'}) if exists($parameters{'fen'});
    $position = lc($parameters{'position'}) if exists($parameters{'position'});
    $font = $parameters{'font'} if exists($parameters{'font'});
    $border = lc($parameters{'border'}) if exists($parameters{'border'});
    $corner = lc($parameters{'corner'}) if exists($parameters{'corner'});
    $legend = lc($parameters{'legend'}) if exists($parameters{'legend'});
    $size = lc($parameters{'size'}) if exists($parameters{'size'});
    $type = $font2map{$font};

    my $pgn = new Chess::PGN::Parse($file) or die "Can't open $file: $!\n";
    my $games_ref = $pgn->read_all({save_comments => 'yes'});
    my $arrayref;
    my @moves;
    my %comments;
    my %tags;
    my %ravs;
    my %nags;
    my @epd;
    my @rows;
    my $result;
    my $date;
    my @date;

    $file =~ s/.pgn//;
    $file = uc($file);

    print <<"HEADER";
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="pgn.xsl"?>
<!DOCTYPE CHESSGAMES SYSTEM "pgn.dtd">
<CHESSGAMES NAME="$file Games">
HEADER
    foreach  (@{$games_ref}) {
        my $move = 1;
        my $n = 1;
        my $white;
        my $ckey;
        my @movesmade;
        $arrayref = $_;
        @moves = ();
        %comments = ();
        %tags = ();
        %nags = ();
        %ravs = ();

        print "\t\t<GAME>\n";
        foreach my $key  (keys %{$arrayref}) {
            my $ref = %{$arrayref}->{$key};
            if (ref($ref)) {
                if ($key eq 'GameMoves') {
                    @moves = @{$ref};
                }
                elsif ($key eq 'GameComments') {
                    %comments = %{$ref};
                    foreach  (keys %comments) {
                        my $t = $comments{$_};
                        my $NAG;
                        my $RAV;
                        my $COMMENT;

                        ($t,$RAV) = deLIMIT($t,'\(','\)');
                        ($t,$COMMENT) = deLIMIT($t,'\{','\}');
                        ($t,$NAG) = deLIMIT($t,'\$','\D');
                        if ($RAV) {
                            $ravs{$_} = $RAV;
                        }
                        if ($NAG ne '') {
                            $nags{$_} = $NAG;
                        }
                        if ($COMMENT) {
                            $comments{$_} = $COMMENT;
                        }
                        else {
                        	delete($comments{$_});
                        }
                   }
                }
            }
            elsif ($ref) {
                if ($key ne 'Game') {
                    $tags{$key} = $ref;
                }
            }
        }
        @epd = epdlist( @moves );
        @rows = epdstr(epd => $epd[-1],type => $type,border => $border,corner => $corner,legend => $legend);
        print "\t\t<TAGLIST>\n";
        foreach  ('Event','Site','Date','Round','White','Black','Result') {
            if ($_ eq 'Result') {
                $result = $tags{'Result'};

                print "\t\t\t<Result GAMERESULT=";
                if ($result eq '1-0') {
                    $result = 'WHITEWIN';
                }
                elsif ($result eq '0-1') {
                    $result = 'BLACKWIN';
                }
                elsif ($result eq '1/2-1/2') {
                    $result = 'DRAW';
                }
                else {
                    $result = 'UNKNOWN';
                }
                print "\"$result\"/>\n";
            }
            elsif ($_ eq 'Date') {
                $date = $tags{'Date'};
                @date = split(/\./,$date);

                print "\t\t\t<Date YEAR=\"$date[0]\" MONTH=\"$date[1]\" DAY=\"$date[2]\"/>\n";
            }
            else {
                print "\t\t\t<$_>$tags{$_}</$_>\n";
            }
            delete($tags{$_});
        }
        foreach  (sort keys %tags) {
            print "\t\t\t<$_>$tags{$_}</$_>\n";
        }
        print "\t\t</TAGLIST>\n";
        print "\t\t<GAMETEXT>\n";
        foreach  (@moves) {
            push(@movesmade,$_);
            if ($n % 2) {
                print "\t\t\t<MOVENUMBER>$move</MOVENUMBER>\n";
                $ckey = "${move}w";
            }
            else {
                $ckey = "${move}b";
                $move++;
            }
            print "\t\t\t<MOVE>$_</MOVE>\n";
            if (%comments and exists($comments{$ckey})) {
                my $s = $comments{$ckey};
                print "\t\t\t<COMMENT>$s</COMMENT>\n";
            }
            if (%nags and exists($nags{$ckey})) {
                my $s = $nags{$ckey};
                if ($s eq '0' and ($position eq 'yes' or $position eq 'nag')) {
                    my @epd = epdlist( @movesmade );
                    my @rows = epdstr(epd => $epd[-1],type => $type,border => $border,corner => $corner,legend => $legend);
                    print "\t\t\t<POSITION FONT=\"$font\" SIZE=\"",$size - 2,"\">\n";
                    foreach  (@rows) {
                        print "\t\t\t\t<ROW>$_</ROW>\n";
                    }
                    print "\t\t\t</POSITION>\n";
                }
                else {
                    print "\t\t\t<NAG>$s</NAG>\n";
                }
            }
            if (%ravs and exists($ravs{$ckey})) {
                my $s = $ravs{$ckey};
                #
                # Note that I don't do anything with RAVS at the moment...
                #
            }
            if ($fen eq 'yes') {
                print "\t\t\t<FENstr>$epd[$move]</FENstr>\n";
            }
            $n++;
        }
        print "\t\t\t<GAMETERMINATION GAMERESULT=\"$result\"/>\n";;
        print "\t\t</GAMETEXT>\n";
        if ($position eq 'yes' or $position eq 'end') {
            print "\t\t<POSITION FONT=\"$font\" SIZE=\"$size\">\n";
            foreach  (@rows) {
                print "\t\t\t<ROW>$_</ROW>\n";
            }
            print "\t\t</POSITION>\n";
        }
        print "\t</GAME>\n";
    }
    print "</CHESSGAMES>\n";
}

sub deLIMIT {
    my $t = shift;
    my $startdelim = shift;
    my $enddelim = shift;
    my $mc = new Text::DelimMatch($startdelim,$enddelim);
    my ($prefix,$match,$remainder) = $mc->match(' ' . $t . ' ');

    if ($match) {
        $match =~ s/^$startdelim//;
        $match =~ s/$enddelim$//;
        return ($prefix or '') . ($remainder or ''),$match;
    }
    else {
        return $t,'';
    }
}

1;
__END__

=head1 NAME

Chess::PGN::Filter - Perl extension for converting PGN files to other formats.

=head1 SYNOPSIS

 #!/usr/bin/perl
 # 
 use strict;
 use warnings;
 use Chess::PGN::Filter;
 
 if ($ARGV[0]) {
     filter(source => $ARGV[0],filtertype => 'XML');
 }

B<OR>
 
 #!/usr/bin/perl
 # 
 use strict;
 use warnings;
 use Chess::PGN::Filter;
 
 if ($ARGV[0]) {
     my %substitutions = (
         hsmyers => 'Myers, Hugh S (ID)'
     );
 
     filter(
         source => $ARGV[0],
         filtertype => 'TEXT',
         substitute => \%substitutions,
         nags => 'yes',
     );
 }

=head1 DESCRIPTION

This is a typical text in one side, different text out the otherside filter module. There are as of
this writing, the following supported choices:

=over

=item 1XML -- Converts from .pgn to .xml using the included pgn.dtd as the validation document. This
is for the most part a one to one transliteration of the PGN standard into XMLese. It does have the
additional virtue of allowing positions to be encoded within the XML output. These are generated by
an embedded NAG of {0} and automatically (user controlled) at the end of each game. As a kind of adjunct
to the position diagrams, pgn.dtd optionally allows each move to include it's FEN string. This allows
scripted animation for web pages generated this information.

=item 1TEXT -- Although the PGN standard is widely available, many program that generate .pgn do so
in an ill-formed way. This mode is an attempt to 'normalize' away the various flaws found in the 'wild'!
This includes things like game text all on a single line without a preceding blank line. Or castling
indicated with zeros rather than the letter 'O'. There is at least one application that carefully indents
the first move! The list of oddities is probably as long as the list of applications.

=back

Owing to a dearth of imagination, there is but one routine in the module:

=head2 filter(I<parameter_hash>)

There are however, a small host of known keys for C<parameter_hash> and they are as follows:

=over

=item * keys common to all filtertypes

=over

=item * filtertype -- essentially which filter to use. Values implemented are:

=over

=item 1XML -- converts from .pgn text in, to .xml file out. Validated by supplied pgn.dtd.

=item 1TEXT -- converts from .pgn text in, to .pgn out with reformatting of ill-formed text and
other modifications possible. Global correction of tag values, error checking for game text termination etc. Blank
lines and paragraph wrapping emplemented to match PGN standard.

=back

=item * source -- name of file to convert, with output sent to STDOUT.

=back

=item * keys for filtertype TEXT

=over

=item * substitute -- simple text substitution mechanism applied globally (file scope) to all tag text.

This is actually a hash reference where the hash reffered to has the form of (text_to_change => text_to_change_to). For instance:

 my %substitutions = (
     hsmyers => 'Myers, Hugh S (ID)'
 );

as used in the B<SYNOPSIS> example would expand my user name into a full version for any tag the former might occur in.

=item * comments -- switch to include/exclude comments (defaults to 'no'.)

=item * ravs -- switch to include/exclude recursive annotated variations (defaults to 'no'.)

=item * nags -- switch to include/exclude numberic annotation glyphs (defaults to 'no'.)

=item * ECO -- switch to include/exclude ECO tag (defaults to 'yes'.)

=item * NIC -- switch to include/exclude NIC tag (defaults to 'no'.)

=item * Opening -- switch to include/exclude Opening tag (defaults to 'yes'.)

=back

=item * keys for filtertype XML. These control the appearence of embedded positions reached 
during the game as well as the final position of the game.

=over

=item * fen -- switch to include/exclude fen information for each move (defaults to 'no'.)

=item * position -- switch to control position diagrams in a game (defaults to 'yes'.)

Possible values are:

=over

=item * 'nag' -- insert diagram for each {0} in game text.

=item * 'end' -- insert diagram at end of game.

=item * 'no' -- no diagrams from either source.

=item * 'yes' -- create diagrams based on both embedded nags as well as at end of game.

=back

=item * font -- name of font to specify for embedded diagrams (default is 'Chess Kingdom'.)

Following list shows font name, font designer. They are available from L<http://www.enpassant.dk/chess/fonteng.htm>

=over

=item 1Chess Cases -- Matthieu Leschemelle

=item 1Chess Adventurer -- Armando H. Marroquin

=item 1Chess Alfonso-X -- Armando H. Marroquin

=item 1Chess Alpha -- Eric Bentzen

=item 1Chess Berlin -- Eric Bentzen

=item 1Chess Condal -- Armando H. Marroquin

=item 1Chess Harlequin -- Armando H. Marroquin

=item 1Chess Kingdom -- Armando H. Marroquin

=item 1Chess Leipzig -- Armando H. Marroquin

=item 1Chess Line -- Armando H. Marroquin

=item 1Chess Lucena -- Armando H. Marroquin

=item 1Chess Magnetic -- Armando H. Marroquin

=item 1Chess Mark -- Armando H. Marroquin

=item 1Chess Marroquin -- Armando H. Marroquin

=item 1Chess Maya -- Armando H. Marroquin

=item 1Chess Mediaeval -- Armando H. Marroquin

=item 1Chess Mérida -- Armando H. Marroquin

=item 1Chess Millennia -- Armando H. Marroquin

=item 1Chess Miscel -- Armando H. Marroquin

=item 1Chess Montreal -- Gary Katch

=item 1Chess Motif -- Armando H. Marroquin

=item 1Chess Plain -- Alan Hickey

=item 1Chess Regular -- Alistair Scott

=item 1Chess Usual -- Armando H. Marroquin

=item 1Chess Utrecht -- Hans Bodlaender

=item 1Tilburg -- Eric Schiller and Bill Cone

=item 1Traveller Standard v3 -- Alan Cowderoy

=back

=item * border, values can be either 'single' or 'double' (default is 'single'.)

=item * corner, values can be either 'square' or 'rounded' (default is 'square'.)

=item * legend, values can be either 'yes' or 'no' (default is 'no'.)

=item * size, value ranging from 1 to 6 that controls the size of the embedded diagram (default is 5.)

=back

B<Note> -- not all fonts support all combinations of 'border', 'corner' and 'legend'. No warnings or
errors will be generated by unsupported options, you get the best a font can do, no more!

=head2 EXPORT

=over

=item filter - given a source file and specification, convert to supported output. See details in B<Description>.

=back

=head2 DEPENDENCIES

=over

=item use Chess::PGN::Parse;

=item use Chess::PGN::EPD;

=item use Text::DelimMatch;

=back

=head1 TODO

=over

=item * Add other output types, PDF, DHTML, LaTeX.

=item * Handle recursive annotation variations...what you call RAVs!

=back

=head1 KNOWN BUGS

None known; Unknown? Of course, though I try to be neat...

=head1 AUTHOR

B<I<Hugh S. Myers>>

=over

=item Always: hsmyers@sdragons.com

=back

=cut
