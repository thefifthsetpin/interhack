# add a tab for Elbereth when you're writing stuff on the ground
# also adds a tab for wand types
# authored by Eidolos
# revised by thefifthsetpin

my @el_wands = (
	'Alum'     ,'Balsa'     ,'Brass' ,'Copper'
	,'Crystal' ,'Curved'    ,'Ebony' ,'Fork'
	,'Glass'   ,'Hexagonal' ,'Irid'  ,'Iron'
	,'Jewel'   ,'Long'      ,'Maple' ,'Marble'
	,'Oak'     ,'Pine'      ,'Plat'  ,'Runed'
	,'Short'   ,'Silver'    ,'Spike' ,'Steel'
	,'Tin'     ,'Uran'      ,'Zinc') unless @el_wands;

my $used;
sub el_complete # {{{
{
	my($word) = @_;
  # just floors.  You can't engrave on walls or ceilings.
	my $location = "(maw|air|bottom|water|ice|lava|bridge|altar|headstone|fountain|floor|ground|frost|dust)";
	my $newVerb = "(write|engrave|melt|burn|scrible|scrawl)( strangely)?";
	my $addVerb = "add to the( weird)? (writing|epitaph|engraving|text|graffiti|scrawl)( (melted|burned))?"; # not to be mistaken with adverb.
	my $isE = $word eq 'Elbereth'; # better form would probably have been to make an Elbereth method and a Wand method.
  my @lengths;
	if($isE){
		# Given no prompting string from the player, we default to "Elbereth"  
		make_tab qr/^What do you want to ($newVerb|$addVerb) (on|in|into) the $location here\? \s*$/i => "$word\n";
		@lengths = (19,9);
	}else{
		@lengths = (19 - 19 % length($word),9 - 9 % length($word));
	}


	# It'd be rediculous to auto-complete from the middle of a wand name.  So we just don't do that.
	my $offsetSentinal = $isE ? length($word) : 1;
	for($offset = 0; $offset < $offsetSentinal; $offset++){
		for($i = 1; $i<=@lengths[0];$i++){
			my $start = '';
			if($offset != 0){
				$start .= '\s*';
			}
			for($j = 0; $j < $i; $j++){
				my $index = ($offset +$j) % length($word);
				if($index == 0){
					$start .= '\s*';
				}
				$start .= substr($word,$index,1);
			}
			if($used{uc($start)}){
				next;
			}
			$used{uc($start)} = 1;
			my $length;
			if($i < @lengths[1]){
				$length = @lengths[$i % 2];
			}else{
				$length = @lengths[0];
			}
			if(!$isE){
				$length -= $length % length($word);
			}
			my $end = '';
			for(; $j < $length; $j++){
				my $index = ($offset +$j) % length($word);
				if($index == 0 && !$isE){
					$end .= ' ';
				}
				$end .= substr($word,$index,1);
			}
			if(!$isE){
				$end = uc($end);
			}
			if($offset == 0){
				make_tab qr/^What do you want to ($newVerb|$addVerb) (on|in|into) the $location here\? $start\s*$/i => "$end\n";
			}else{
				make_tab qr/^What do you want to $addVerb (on|in|into) the $location here\? $start\s*$/i => "$end\n";;
			}
		}
	}
} # }}}

foreach (('Elbereth',@el_wands)) {
	el_complete($_);
}

