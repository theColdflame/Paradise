#define BUTTON_COOLDOWN 60 // cant delay the bomb forever
#define BUTTON_DELAY	50 //five seconds

/obj/machinery/syndicatebomb
	icon = 'icons/obj/assemblies.dmi'
	name = "syndicate bomb"
	icon_state = "syndicate-bomb"
	desc = "A large and menacing device. Can be bolted down with a wrench."

	anchored = 0
	density = 0
	layer = BELOW_MOB_LAYER //so people can't hide it and it's REALLY OBVIOUS
	unacidable = 1

	var/datum/wires/syndicatebomb/wires = null
	var/minimum_timer = 90
	var/timer_set = 90
	var/maximum_timer = 60000

	var/can_unanchor = TRUE

	var/open_panel = FALSE 	//are the wires exposed?
	var/active = FALSE		//is the bomb counting down?
	var/defused = FALSE		//is the bomb capable of exploding?
	var/obj/item/bombcore/payload = /obj/item/bombcore
	var/beepsound = 'sound/items/timer.ogg'
	var/delayedbig = FALSE	//delay wire pulsed?
	var/delayedlittle  = FALSE	//activation wire pulsed?
	var/obj/effect/countdown/syndicatebomb/countdown

	var/next_beep
	var/detonation_timer
	var/explode_now = FALSE

/obj/machinery/syndicatebomb/proc/try_detonate(ignore_active = FALSE)
	. = (payload in src) && (active || ignore_active) && !defused
	if(.)
		payload.detonate()

/obj/machinery/syndicatebomb/process()
	if(!active)
		fast_processing -= src
		detonation_timer = null
		next_beep = null
		countdown.stop()
		return

	if(!isnull(next_beep) && (next_beep <= world.time))
		var/volume
		switch(seconds_remaining())
			if(0 to 5)
				volume = 50
			if(5 to 10)
				volume = 40
			if(10 to 15)
				volume = 30
			if(15 to 20)
				volume = 20
			if(20 to 25)
				volume = 10
			else
				volume = 5
		playsound(loc, beepsound, volume, 0)
		next_beep = world.time + 10

	if(active && !defused && ((detonation_timer <= world.time) || explode_now))
		active = FALSE
		timer_set = initial(timer_set)
		update_icon()
		try_detonate(TRUE)
	//Counter terrorists win
	else if(!active || defused)
		if(defused && payload in src)
			payload.defuse()
			countdown.stop()
			fast_processing -= src

/obj/machinery/syndicatebomb/New()
	wires 	= new(src)
	if(payload)
		payload = new payload(src)
	update_icon()
	countdown = new(src)
	..()

/obj/machinery/syndicatebomb/Destroy()
	QDEL_NULL(wires)
	QDEL_NULL(countdown)
	fast_processing -= src
	return ..()

/obj/machinery/syndicatebomb/examine(mob/user)
	..(user)
	to_chat(user, "A digital display on it reads \"[seconds_remaining()]\".")

/obj/machinery/syndicatebomb/update_icon()
	icon_state = "[initial(icon_state)][active ? "-active" : "-inactive"][open_panel ? "-wires" : ""]"

/obj/machinery/syndicatebomb/proc/seconds_remaining()
	if(active)
		. = max(0, round((detonation_timer - world.time) / 10))
	else
		. = timer_set

/obj/machinery/syndicatebomb/attackby(obj/item/I, mob/user, params)
	if(iswrench(I) && can_unanchor)
		if(!anchored)
			if(!isturf(loc) || isspaceturf(loc))
				to_chat(user, "<span class='notice'>The bomb must be placed on solid ground to attach it.</span>")
			else
				to_chat(user, "<span class='notice'>You firmly wrench the bomb to the floor.</span>")
				playsound(loc, I.usesound, 50, 1)
				anchored = 1
				if(active)
					to_chat(user, "<span class='notice'>The bolts lock in place.</span>")
		else
			if(!active)
				to_chat(user, "<span class='notice'>You wrench the bomb from the floor.</span>")
				playsound(loc, I.usesound, 50, 1)
				anchored = 0
			else
				to_chat(user, "<span class='warning'>The bolts are locked down!</span>")

	else if(isscrewdriver(I))
		open_panel = !open_panel
		update_icon()
		to_chat(user, "<span class='notice'>You [open_panel ? "open" : "close"] the wire panel.</span>")

	else if(istype(I, /obj/item/wirecutters) || istype(I, /obj/item/device/multitool) || istype(I, /obj/item/device/assembly/signaler ))
		if(open_panel)
			wires.Interact(user)

	else if(iscrowbar(I))
		if(open_panel && wires.IsAllCut())
			if(payload)
				to_chat(user, "<span class='notice'>You carefully pry out [payload].</span>")
				payload.loc = user.loc
				payload = null
			else
				to_chat(user, "<span class='warning'>There isn't anything in here to remove!</span>")
		else if(open_panel)
			to_chat(user, "<span class='warning'>The wires connecting the shell to the explosives are holding it down!</span>")
		else
			to_chat(user, "<span class='warning'>The cover is screwed on, it won't pry off!</span>")
	else if(istype(I, /obj/item/bombcore))
		if(!payload)
			if(!user.drop_item())
				return
			payload = I
			to_chat(user, "<span class='notice'>You place [payload] into [src].</span>")
			payload.forceMove(src)
		else
			to_chat(user, "<span class='notice'>[payload] is already loaded into [src], you'll have to remove it first.</span>")
	else if(iswelder(I))
		if(payload || !wires.IsAllCut() || !open_panel)
			return
		var/obj/item/weldingtool/WT = I
		if(!WT.isOn())
			return
		if(WT.get_fuel() < 5) //uses up 5 fuel.
			to_chat(user, "<span class='warning'>You need more fuel to complete this task!</span>")
			return

		playsound(loc, WT.usesound, 50, 1)
		to_chat(user, "<span class='notice'>You start to cut the [src] apart...</span>")
		if(do_after(user, 20*I.toolspeed, target = src))
			if(!WT.isOn() || !WT.remove_fuel(5, user))
				return
			to_chat(user, "<span class='notice'>You cut the [src] apart.</span>")
			new /obj/item/stack/sheet/plasteel(loc, 5)
			qdel(src)
	else
		return ..()

/obj/machinery/syndicatebomb/attack_ghost(mob/user)
	interact(user)

/obj/machinery/syndicatebomb/attack_hand(mob/user)
	interact(user)

/obj/machinery/syndicatebomb/attack_ai()
	return

/obj/machinery/syndicatebomb/interact(mob/user)
	if(wires && open_panel)
		wires.Interact(user)
	if(!open_panel && can_interact(user))
		if(!active)
			spawn()
				settings(user)
				return
		else if(anchored)
			to_chat(user, "<span class='notice'>The bomb is bolted to the floor!</span>")

/obj/machinery/syndicatebomb/proc/can_interact(mob/user)
	if(user.can_advanced_admin_interact())
		return TRUE
	if(!isliving(user))
		return FALSE
	if(user.incapacitated())
		return FALSE
	if(!Adjacent(user))
		return FALSE
	return TRUE

/obj/machinery/syndicatebomb/proc/activate()
	active = TRUE
	fast_processing += src
	countdown.start()
	next_beep = world.time + 10
	detonation_timer = world.time + (timer_set * 10)
	playsound(loc, 'sound/machines/click.ogg', 30, 1)

/obj/machinery/syndicatebomb/proc/settings(mob/user)
	var/new_timer = input(user, "Please set the timer.", "Timer", "[timer_set]") as num
	if(can_interact(user)) //No running off and setting bombs from across the station
		timer_set = Clamp(new_timer, minimum_timer, maximum_timer)
		loc.visible_message("<span class='notice'>[bicon(src)] timer set for [timer_set] seconds.</span>")
	if(alert(user,"Would you like to start the countdown now?",,"Yes","No") == "Yes" && can_interact(user))
		if(defused || active)
			if(defused)
				loc.visible_message("<span class='notice'>[bicon(src)] Device error: User intervention required.</span>")
			return
		else
			loc.visible_message("<span class='danger'>[bicon(src)] [timer_set] seconds until detonation, please clear the area.</span>")
			activate()
			update_icon()
			add_fingerprint(user)

			var/turf/bombturf = get_turf(src)
			var/area/A = get_area(bombturf)
			if(payload && !istype(payload, /obj/item/bombcore/training))
				msg_admin_attack("[key_name_admin(user)] has primed a [name] ([payload]) for detonation at <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[bombturf.x];Y=[bombturf.y];Z=[bombturf.z]'>[A.name] (JMP)</a>.")
				log_game("[key_name(user)] has primed a [name] ([payload]) for detonation at [A.name] ([bombturf.x], [bombturf.y], [bombturf.z])")
				payload.adminlog = "\The [src] that [key_name(user)] had primed detonated!"

/obj/machinery/syndicatebomb/proc/isWireCut(var/index)
	return wires.IsIndexCut(index)

///Bomb Subtypes///

/obj/machinery/syndicatebomb/training
	name = "training bomb"
	icon_state = "training-bomb"
	desc = "A salvaged syndicate device gutted of its explosives to be used as a training aid for aspiring bomb defusers."
	payload = /obj/item/bombcore/training

/obj/machinery/syndicatebomb/badmin
	name = "generic summoning badmin bomb"
	desc = "Oh god what is in this thing?"
	payload = /obj/item/bombcore/badmin/summon

/obj/machinery/syndicatebomb/badmin/clown
	name = "clown bomb"
	icon_state = "clown-bomb"
	desc = "HONK."
	payload = /obj/item/bombcore/badmin/summon/clown
	beepsound = 'sound/items/bikehorn.ogg'

/obj/machinery/syndicatebomb/empty
	name = "bomb"
	icon_state = "base-bomb"
	desc = "An ominous looking device designed to detonate an explosive payload. Can be bolted down using a wrench."
	payload = null
	open_panel = TRUE
	timer_set = 120

/obj/machinery/syndicatebomb/empty/New()
	..()
	wires.CutAll()

/obj/machinery/syndicatebomb/self_destruct
	name = "self destruct device"
	desc = "Do not taunt. Warranty invalid if exposed to high temperature. Not suitable for agents under 3 years of age."
	payload = /obj/item/bombcore/large
	can_unanchor = FALSE

///Bomb Cores///

/obj/item/bombcore
	name = "bomb payload"
	desc = "A powerful secondary explosive of syndicate design and unknown composition, it should be stable under normal conditions..."
	icon = 'icons/obj/assemblies.dmi'
	icon_state = "bombcore"
	item_state = "eshield0"
	w_class = WEIGHT_CLASS_NORMAL
	origin_tech = "syndicate=5;combat=6"
	burn_state = FLAMMABLE //Burnable (but the casing isn't)
	var/adminlog = null
	var/range_heavy = 3
	var/range_medium = 9
	var/range_light = 17
	var/range_flame = 17

/obj/item/bombcore/ex_act(severity) //Little boom can chain a big boom
	detonate()


/obj/item/bombcore/burn()
	detonate()
	..()

/obj/item/bombcore/proc/detonate()
	if(adminlog)
		message_admins(adminlog)
		log_game(adminlog)
	explosion(get_turf(src), range_heavy, range_medium, range_light, flame_range = range_flame)
	if(loc && istype(loc, /obj/machinery/syndicatebomb))
		qdel(loc)
	qdel(src)

/obj/item/bombcore/proc/defuse()
//Note: 	Because of how var/defused is used you shouldn't override this UNLESS you intend to set the var to 0 or
//			otherwise remove the core/reset the wires before the end of defuse(). It will repeatedly be called otherwise.

///Bomb Core Subtypes///

/obj/item/bombcore/training
	name = "dummy payload"
	desc = "A nanotrasen replica of a syndicate payload. Its not intended to explode but to announce that it WOULD have exploded, then rewire itself to allow for more training."
	origin_tech = null
	var/defusals = 0
	var/attempts = 0

/obj/item/bombcore/training/proc/reset()
	var/obj/machinery/syndicatebomb/holder = loc
	if(istype(holder))
		if(holder.wires)
			holder.wires.Shuffle()
		holder.defused = 0
		holder.open_panel = 0
		holder.delayedbig = FALSE
		holder.delayedlittle = FALSE
		holder.explode_now = FALSE
		holder.update_icon()
		holder.updateDialog()

/obj/item/bombcore/training/detonate()
	var/obj/machinery/syndicatebomb/holder = loc
	if(istype(holder))
		attempts++
		holder.loc.visible_message("<span class='danger'>[bicon(holder)] Alert: Bomb has detonated. Your score is now [defusals] for [attempts]. Resetting wires...</span>")
		reset()
	else
		qdel(src)

/obj/item/bombcore/training/defuse()
	var/obj/machinery/syndicatebomb/holder = loc
	if(istype(holder))
		attempts++
		defusals++
		holder.loc.visible_message("<span class='notice'>[bicon(holder)] Alert: Bomb has been defused. Your score is now [defusals] for [attempts]! Resetting wires in 5 seconds...</span>")
		sleep(50)	//Just in case someone is trying to remove the bomb core this gives them a little window to crowbar it out
		if(istype(holder))
			reset()

/obj/item/bombcore/badmin
	name = "badmin payload"
	desc = "If you're seeing this someone has either made a mistake or gotten dangerously savvy with var editing!"
	origin_tech = null

/obj/item/bombcore/badmin/defuse() //because we wouldn't want them being harvested by players
	var/obj/machinery/syndicatebomb/B = loc
	qdel(B)
	qdel(src)

/obj/item/bombcore/badmin/summon
	var/summon_path = /obj/item/reagent_containers/food/snacks/cookie
	var/amt_summon = 1

/obj/item/bombcore/badmin/summon/detonate()
	var/obj/machinery/syndicatebomb/B = src.loc
	for(var/i = 0; i < amt_summon; i++)
		var/atom/movable/X = new summon_path
		X.admin_spawned = TRUE
		X.loc = get_turf(src)
		if(prob(50))
			for(var/j = 1, j <= rand(1, 3), j++)
				step(X, pick(NORTH,SOUTH,EAST,WEST))
	qdel(B)
	qdel(src)

/obj/item/bombcore/badmin/summon/clown
	summon_path = /mob/living/simple_animal/hostile/retaliate/clown
	amt_summon 	= 100

/obj/item/bombcore/badmin/summon/clown/defuse()
	playsound(src.loc, 'sound/misc/sadtrombone.ogg', 50)
	..()

/obj/item/bombcore/large
	name = "large bomb payload"
	range_heavy = 5
	range_medium = 10
	range_light = 20
	range_flame = 20

/obj/item/bombcore/large/underwall
	layer = ABOVE_OPEN_TURF_LAYER

/obj/item/bombcore/miniature
	name = "small bomb core"
	w_class = WEIGHT_CLASS_SMALL
	range_heavy = 1
	range_medium = 2
	range_light = 4
	range_flame = 2

/obj/item/bombcore/chemical
	name = "chemical payload"
	desc = "An explosive payload designed to spread chemicals, dangerous or otherwise, across a large area. It is able to hold up to four chemical containers, and must be loaded before use."
	origin_tech = "combat=4;materials=3"
	icon_state = "chemcore"
	var/list/beakers = list()
	var/max_beakers = 1
	var/spread_range = 5
	var/temp_boost = 50
	var/time_release = 0

/obj/item/bombcore/chemical/detonate()

	if(time_release > 0)
		var/total_volume = 0
		for(var/obj/item/reagent_containers/RC in beakers)
			total_volume += RC.reagents.total_volume

		if(total_volume < time_release) // If it's empty, the detonation is complete.
			if(loc && istype(loc, /obj/machinery/syndicatebomb))
				qdel(loc)
			qdel(src)
			return

		var/fraction = time_release/total_volume
		var/datum/reagents/reactants = new(time_release)
		reactants.my_atom = src
		for(var/obj/item/reagent_containers/RC in beakers)
			RC.reagents.trans_to(reactants, RC.reagents.total_volume*fraction, 1, 1, 1)
		chem_splash(get_turf(src), spread_range, list(reactants), temp_boost)

		// Detonate it again in one second, until it's out of juice.
		addtimer(src, "detonate", 10)

	// If it's not a time release bomb, do normal explosion

	var/list/reactants = list()

	for(var/obj/item/reagent_containers/glass/G in beakers)
		reactants += G.reagents

	for(var/obj/item/slime_extract/S in beakers)
		if(S.Uses)
			for(var/obj/item/reagent_containers/glass/G in beakers)
				G.reagents.trans_to(S, G.reagents.total_volume)

			if(S && S.reagents && S.reagents.total_volume)
				reactants += S.reagents

	if(!chem_splash(get_turf(src), spread_range, reactants, temp_boost))
		playsound(loc, 'sound/items/Screwdriver2.ogg', 50, 1)
		return // The Explosion didn't do anything. No need to log, or disappear.

	if(adminlog)
		message_admins(adminlog)
		log_game(adminlog)

	playsound(loc, 'sound/effects/bamf.ogg', 75, 1, 5)

	if(loc && istype(loc, /obj/machinery/syndicatebomb))
		qdel(loc)
	qdel(src)

/obj/item/bombcore/chemical/attackby(obj/item/I, mob/user, params)
	if(iscrowbar(I) && beakers.len > 0)
		playsound(loc, I.usesound, 50, 1)
		for (var/obj/item/B in beakers)
			B.loc = get_turf(src)
			beakers -= B
		return
	else if(istype(I, /obj/item/reagent_containers/glass/beaker) || istype(I, /obj/item/reagent_containers/glass/bottle))
		if(beakers.len < max_beakers)
			if(!user.drop_item())
				return
			beakers += I
			to_chat(user, "<span class='notice'>You load [src] with [I].</span>")
			I.loc = src
		else
			to_chat(user, "<span class='warning'>The [I] wont fit! The [src] can only hold up to [max_beakers] containers.</span>")
			return
	..()

/obj/item/bombcore/chemical/CheckParts(list/parts_list)
	..()
	// Using different grenade casings, causes the payload to have different properties.
	var/obj/item/stock_parts/matter_bin/MB = locate(/obj/item/stock_parts/matter_bin) in src
	if(MB)
		max_beakers += MB.rating	// max beakers = 2-5.
		qdel(MB)
	for(var/obj/item/grenade/chem_grenade/G in src)

		if(istype(G, /obj/item/grenade/chem_grenade/large))
			var/obj/item/grenade/chem_grenade/large/LG = G
			max_beakers += 1 // Adding two large grenades only allows for a maximum of 7 beakers.
			spread_range += 2 // Extra range, reduced density.
			temp_boost += 50 // maximum of +150K blast using only large beakers. Not enough to self ignite.
			for(var/obj/item/slime_extract/S in LG.beakers) // And slime cores.
				if(beakers.len < max_beakers)
					beakers += S
					S.loc = src
				else
					S.loc = get_turf(src)

		if(istype(G, /obj/item/grenade/chem_grenade/cryo))
			spread_range -= 1 // Reduced range, but increased density.
			temp_boost -= 100 // minimum of -150K blast.

		if(istype(G, /obj/item/grenade/chem_grenade/pyro))
			temp_boost += 150 // maximum of +350K blast, which is enough to self ignite. Which means a self igniting bomb can't take advantage of other grenade casing properties. Sorry?

		if(istype(G, /obj/item/grenade/chem_grenade/adv_release))
			time_release += 50 // A typical bomb, using basic beakers, will explode over 2-4 seconds. Using two will make the reaction last for less time, but it will be more dangerous overall.

		for(var/obj/item/reagent_containers/glass/B in G)
			if(beakers.len < max_beakers)
				beakers += B
				B.loc = src
			else
				B.loc = get_turf(src)

		qdel(G)

///Syndicate Detonator (aka the big red button)///

/obj/item/device/syndicatedetonator
	name = "big red button"
	desc = "Your standard issue bomb synchronizing button. Five second safety delay to prevent 'accidents'."
	icon = 'icons/obj/assemblies.dmi'
	icon_state = "bigred"
	item_state = "electronic"
	w_class = WEIGHT_CLASS_TINY
	origin_tech = "syndicate=3"
	var/timer = 0
	var/detonated =	0
	var/existant =	0

/obj/item/device/syndicatedetonator/attack_self(mob/user)
	if(timer < world.time)
		for(var/obj/machinery/syndicatebomb/B in machines)
			if(B.active)
				B.detonation_timer = world.time + BUTTON_DELAY
				detonated++
			existant++
		playsound(user, 'sound/machines/click.ogg', 20, 1)
		to_chat(user, "<span class='notice'>[existant] found, [detonated] triggered.</span>")
		if(detonated)
			var/turf/T = get_turf(src)
			var/area/A = get_area(T)
			detonated--
			message_admins("[key_name_admin(user)] has remotely detonated [detonated ? "syndicate bombs" : "a syndicate bomb"] using a [name] at <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>[A.name] (JMP)</a>.")
			bombers += "[key_name(user)] has remotely detonated [detonated ? "syndicate bombs" : "a syndicate bomb"] using a [name] at [A.name] ([T.x],[T.y],[T.z])"
			log_game("[key_name(user)] has remotely detonated [detonated ? "syndicate bombs" : "a syndicate bomb"] using a [name] at [A.name] ([T.x],[T.y],[T.z])")
		detonated =	0
		existant =	0
		timer = world.time + BUTTON_COOLDOWN

#undef BUTTON_COOLDOWN
#undef BUTTON_DELAY