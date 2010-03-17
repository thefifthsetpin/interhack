# add a tab for Elbereth when you're writing stuff on the ground
# also adds a tab for wand types
# authored by Eidolos
# revised by thefifthsetpin


# Some things that characters tend to write.
our @engrave_wands = (
	'Alum'     ,'Balsa'     ,'Brass' ,'Copper'
	,'Crystal' ,'Curved'    ,'Ebony' ,'Fork'
	,'Glass'   ,'Hexagonal' ,'Irid'  ,'Iron',
	,'Jewel'   ,'Long'      ,'Maple' ,'Marble'
	,'Oak'     ,'Pine'      ,'Plat'  ,'Runed'
	,'Short'   ,'Silver'    ,'Spike' ,'Steel'
	,'Tin'     ,'Uran'      ,'Zinc'
	,'_-2-1_0_1_2_3_4_5' # A very dangerous way to determine the enchantment of a stackable weapon.
	, 'Sokoban', 'Mines') unless @engrave_wands;

# More locations exist.  These are just the ones you can engrave on.  And I'm not quite sure that you _can_ engrave on an Altar, actually.
my $dust = "(maw|air|bottom|water|ice|lava|bridge|altar|headstone|fountain|floor|ground|frost|dust)";
my $write = "(write|engrave|melt|burn|scrible|scrawl)( strangely)?";
my $add = "add to the( weird)? (writing|epitaph|engraving|text|graffiti|scrawl)( (melted|burned))?"; 
my $in = "(on|in|into)"; 


#	#DEBUG {{{ 
#	#	When uncommented, Prints instead of calling make_tab, so that you can just execute this file.  
#	#	Also reduces the complexity of the boring parts, making the output readable.
#	
#	sub make_tab {
#		my ($matching, $tabstring) = @_;
#		print "$matching => \"$tabstring\"";
#	}
#	
#	@engrave_wands = ('Jeweled');
#	$dust = "dust"; 
#	$write = "write";
#	$add = "add to the writing";
#	$in = "in";
#	
#	
#	#DEBUG }}} 


my $usedKeys;
foreach $word (('Elbereth',@engrave_wands))
{ # {{{
	my $isE = $word eq 'Elbereth'; # better form would probably have been to make an Elbereth method and a Wand method.

	if($isE){
		# Given no prompting from the player, we default to "Elbereth".
		make_tab qr/^What do you want to ($write|$add) $in the $dust here\? \s*$/ => "$word\n";
	}

  my @lengths = (19,9);

	if(!$isE){ 
		# Given, for example, "ver S", we don't auto complete to "ver Silver".
		# Thus, we don't encourage characters to end an engraving mid-word, like "Silver Sil"
		# Instead, we truncate the lengths to be multiples of length($word).

		# Obviously, an exception is made for Elbereth, which we'll happily complete from pretty much anything
		
		@lengths = map(sub {return $_ - $_% length($word); }->(),@lengths);
	}


	# It'd be rediculous to auto-complete from the middle of a wand name.  So we just don't do that.
	my $offsetSentinal = $isE ? length($word) : 1;
	for($offset = 0; $offset < $offsetSentinal; $offset++){
		for($i = 1; $i<=@lengths[0];$i++){
			# Special hanlding of 'e' => "rethElber" to override 'E' => "lberethE"
			my $specialCase = $isE && 1 == $i && 3 == $offset;

			my $key = '';
			my $start = '';
			my $end = '';

			if($offset != 0){
				$start .= '\s*';
			}
			for($j = 0; $j < $i; $j++){
				my $index = ($offset +$j) % length($word);
				if($index == 0){
					$start .= '\s*';
				}
				my $val = substr($word,$index,1);
				$start .= $val;
				$key .= $val;
			}

			if($usedKeys{uc($key)}){
				if(!$specialCase){
					next;
				}
			}
			$usedKeys{uc($key)} = 1;

			my $length;
			if($i < @lengths[1]){
				$length = @lengths[$i % @lengths];
			}else{
				$length = @lengths[0];
			}

			for(; $j < $length; $j++){
				my $index = ($offset +$j) % length($word);
				if($index == 0 && !$isE){
					$end .= ' '; # improves readability.  Skipped for E so that we can squeeze in a few more E's before we run out of space. 
				}
				$end .= substr($word,$index,1);
			}
			if($specialCase){
				make_tab qr/^What do you want to $add $in the $dust here\? $start\s*$/ => "$end\n";
			}elsif($offset == 0){
				make_tab qr/^What do you want to ($write|$add) $in the $dust here\? $start\s*$/i => "$end\n";
			}else{
				make_tab qr/^What do you want to $add $in the $dust here\? $start\s*$/i => "$end\n";;
			}
		}
	}
} # }}}
