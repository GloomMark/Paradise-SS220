#define DEFAULT_METEOR_LIFETIME 3 MINUTES
#define MAP_EDGE_PAD 5

//Meteors probability of spawning during a given wave
GLOBAL_LIST_INIT(meteors_normal, list(/obj/effect/meteor/dust = 3, /obj/effect/meteor/medium = 8, /obj/effect/meteor/big = 3,
						/obj/effect/meteor/flaming = 1, /obj/effect/meteor/irradiated = 3)) //for normal meteor event

GLOBAL_LIST_INIT(meteors_threatening, list(/obj/effect/meteor/medium = 4, /obj/effect/meteor/big = 8,
						/obj/effect/meteor/flaming = 3, /obj/effect/meteor/irradiated = 3, /obj/effect/meteor/bananium = 1)) //for threatening meteor event

GLOBAL_LIST_INIT(meteors_catastrophic, list(/obj/effect/meteor/medium = 3, /obj/effect/meteor/big = 10,
						/obj/effect/meteor/flaming = 10, /obj/effect/meteor/irradiated = 10, /obj/effect/meteor/bananium = 2, /obj/effect/meteor/meaty = 2, /obj/effect/meteor/meaty/xeno = 2, /obj/effect/meteor/tunguska = 1)) //for catastrophic meteor event

GLOBAL_LIST_INIT(meteors_gore, list(/obj/effect/meteor/meaty = 5, /obj/effect/meteor/meaty/xeno = 1)) //for meaty ore event


///////////////////////////////
//Meteor spawning global procs
///////////////////////////////

/proc/spawn_meteors(number = 10, list/meteortypes)
	for(var/i = 0; i < number; i++)
		spawn_meteor(meteortypes)

/proc/spawn_meteor(list/meteortypes)
	var/turf/pickedstart
	var/turf/pickedgoal
	var/max_i = 10 //number of tries to spawn meteor.
	while(!isspaceturf(pickedstart))
		var/startSide = pick(GLOB.cardinal)
		var/startZ = level_name_to_num(MAIN_STATION)
		pickedstart = pick_edge_loc(startSide, startZ)
		pickedgoal = pick_edge_loc(REVERSE_DIR(startSide), startZ)
		max_i--
		if(max_i <= 0)
			return
	var/Me = pickweight(meteortypes)
	var/obj/effect/meteor/M = new Me(pickedstart, pickedgoal)
	M.dest = pickedgoal

/proc/pick_edge_loc(startSide, Z)
	var/starty
	var/startx
	switch(startSide)
		if(NORTH)
			starty = world.maxy
			startx = rand(1, world.maxx)
		if(EAST)
			starty = rand(1, world.maxy)
			startx = world.maxx
		if(SOUTH)
			starty = 1
			startx = rand(1, world.maxx)
		if(WEST)
			starty = rand(1, world.maxy)
			startx = 1
	return locate(startx, starty, Z)

///////////////////////
//The meteor effect
//////////////////////

/obj/effect/meteor
	name = "\proper the concept of meteor"
	desc = "You should probably run instead of gawking at this."
	icon = 'icons/obj/meteor.dmi'
	icon_state = "small"
	density = TRUE
	var/hits = 4
	var/hitpwr = EXPLODE_HEAVY //Level of ex_act to be called on hit.
	var/dest
	pass_flags = PASSTABLE
	var/heavy = FALSE
	var/meteorsound = 'sound/effects/meteorimpact.ogg'
	var/z_original
	var/lifetime = DEFAULT_METEOR_LIFETIME
	var/timerid = null
	var/list/meteordrop = list(/obj/item/stack/ore/iron)
	var/dropamt = 2

/obj/effect/meteor/Move(atom/newloc, direction, glide_size_override = 0, update_dir = TRUE)
	// Delete if we reach our goal or somehow leave the Z level.
	if(z != z_original || loc == dest)
		qdel(src)
		return FALSE

	. = ..() //process movement...

	if(.)//.. if did move, ram the turf we get in
		var/turf/T = get_turf(loc)
		ram_turf(T)

		if(prob(10) && !ispassmeteorturf(T))//randomly takes a 'hit' from ramming
			get_hit()

/obj/effect/meteor/Destroy()
	if(timerid)
		deltimer(timerid)
	GLOB.meteor_list -= src
	GLOB.move_manager.stop_looping(src) //this cancels the GLOB.move_manager.home_onto() proc
	return ..()

/obj/effect/meteor/Initialize(mapload, target)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_EDGE_TRANSITIONS, ROUNDSTART_TRAIT)
	z_original = z
	GLOB.meteor_list += src
	SpinAnimation()
	timerid = QDEL_IN(src, lifetime)
	chase_target(target)

/obj/effect/meteor/Process_Spacemove(movement_dir, continuous_move)
	return TRUE

/obj/effect/meteor/Bump(atom/A)
	if(A)
		ram_turf(get_turf(A))
		playsound(loc, meteorsound, 40, TRUE)
		if(!istype(A, /obj/structure/railing))
			get_hit()

/obj/effect/meteor/proc/ram_turf(turf/T)
	//first bust whatever is in the turf
	for(var/thing in T)
		var/atom/A = thing
		if(thing == src)
			continue
		if(isliving(thing))
			var/mob/living/living_thing = thing
			living_thing.visible_message("<span class='warning'>[src] slams into [living_thing].</span>", "<span class='userdanger'>[src] slams into you!</span>")
		A.ex_act(hitpwr)

	//then, ram the turf if it still exists
	if(T)
		T.ex_act(hitpwr)

//process getting 'hit' by colliding with a dense object
//or randomly when ramming turfs
/obj/effect/meteor/proc/get_hit()
	hits--
	if(hits <= 0)
		make_debris()
		meteor_effect()
		qdel(src)

/obj/effect/meteor/ex_act()
	return

/obj/effect/meteor/item_interaction(mob/living/user, obj/item/used, list/modifiers)
	if(istype(used, /obj/item/pickaxe))
		make_debris()
		qdel(src)
		return ITEM_INTERACT_COMPLETE

/obj/effect/meteor/proc/make_debris()
	for(var/throws = dropamt, throws > 0, throws--)
		var/thing_to_spawn = pick(meteordrop)
		new thing_to_spawn(get_turf(src))

/obj/effect/meteor/proc/chase_target(atom/chasing, delay = 1)
	set waitfor = FALSE
	if(chasing)
		GLOB.move_manager.home_onto(src, chasing, delay)

/obj/effect/meteor/proc/meteor_effect()
	if(heavy)
		var/sound/meteor_sound = sound(meteorsound)
		var/random_frequency = get_rand_frequency()

		for(var/P in GLOB.player_list)
			var/mob/M = P
			var/turf/T = get_turf(M)
			if(!T || T.z != z)
				continue
			var/dist = get_dist(M.loc, loc)
			shake_camera(M, dist > 20 ? 2 : 4, dist > 20 ? 1 : 3)
			M.playsound_local(loc, null, 50, TRUE, random_frequency, 10, S = meteor_sound)

///////////////////////
//Meteor types
///////////////////////

//Fake
/obj/effect/meteor/fake
	name = "simulated meteor"
	desc = "A simulated meteor for testing shield satellites. How did you see this, anyway?"
	invisibility = INVISIBILITY_MAXIMUM
	density = FALSE
	pass_flags = NONE
	/// The station goal that is simulating this meteor.
	var/datum/station_goal/station_shield/goal
	/// Did we crash into something? Used to avoid falsely reporting success when qdeleted.
	var/failed = FALSE

/obj/effect/meteor/fake/Initialize(mapload)
	. = ..()
	for(var/datum/station_goal/station_shield/found_goal in SSticker.mode.station_goals)
		goal = found_goal
		return

/obj/effect/meteor/fake/Destroy()
	if(!failed)
		succeed()
	goal = null
	return ..()

/obj/effect/meteor/fake/ram_turf(turf/T)
	if(!isspaceturf(T))
		fail()
		return
	for(var/thing in T)
		if(isobj(thing) && !iseffect(thing))
			fail()
			return

/obj/effect/meteor/fake/get_hit()
	return

/obj/effect/meteor/fake/proc/succeed()
	if(istype(goal))
		goal.update_coverage(TRUE, get_turf(src))

/obj/effect/meteor/fake/proc/fail()
	if(istype(goal))
		goal.update_coverage(FALSE, get_turf(src))
	failed = TRUE
	qdel(src)

//Dust
/obj/effect/meteor/dust
	name = "space dust"
	icon_state = "dust"
	pass_flags = PASSTABLE | PASSGRILLE
	hits = 1
	hitpwr = EXPLODE_LIGHT
	meteorsound = 'sound/weapons/gunshots/gunshot_smg.ogg'
	meteordrop = list(/obj/item/stack/ore/glass)

//Medium-sized
/obj/effect/meteor/medium
	name = "meteor"
	dropamt = 3

/obj/effect/meteor/medium/meteor_effect()
	..()
	explosion(loc, 0, 1, 2, 3, 0, cause = name)

//Large-sized
/obj/effect/meteor/big
	name = "big meteor"
	icon_state = "large"
	hits = 6
	heavy = TRUE
	dropamt = 4

/obj/effect/meteor/big/meteor_effect()
	..()
	explosion(loc, 1, 2, 3, 4, 0, cause = name)

//Flaming meteor
/obj/effect/meteor/flaming
	name = "flaming meteor"
	icon_state = "flaming"
	hits = 5
	heavy = TRUE
	meteorsound = 'sound/effects/bamf.ogg'
	meteordrop = list(/obj/item/stack/ore/plasma)

/obj/effect/meteor/flaming/meteor_effect()
	..()
	explosion(loc, 1, 2, 3, 4, 0, 0, 5, cause = name)

//Radiation meteor
/obj/effect/meteor/irradiated
	name = "glowing meteor"
	icon_state = "glowing"
	heavy = TRUE
	meteordrop = list(/obj/item/stack/ore/uranium)


/obj/effect/meteor/irradiated/meteor_effect()
	..()
	explosion(loc, 0, 0, 4, 3, 0, cause = name)
	new /obj/effect/decal/cleanable/greenglow(get_turf(src))
	radiation_pulse(src, 20000, 7, ALPHA_RAD)
	for(var/turf/target_turf in range(loc, 3))
		contaminate_target(target_turf, src, 2000, ALPHA_RAD)
	//Hot take on this one. This often hits walls. It really has to breach into somewhere important to matter. This at leats makes the area slightly dangerous for a bit

/obj/effect/meteor/bananium
	name = "bananium meteor"
	desc = "Well this would be just an awful way to die."
	icon_state = "clownish"
	heavy = TRUE
	meteordrop = list(/obj/item/stack/ore/bananium)

/obj/effect/meteor/bananium/meteor_effect()
	..()
	explosion(loc, 0, 0, 3, 2, 0, cause = name)
	var/turf/current_turf = get_turf(src)
	new /obj/item/grown/bananapeel(current_turf)
	for(var/obj/target in range(4, current_turf))
		if(prob(15))
			target.cmag_act()

//Station buster Tunguska
/obj/effect/meteor/tunguska
	name = "tunguska meteor"
	icon_state = "flaming"
	desc = "Your life briefly passes before your eyes the moment you lay them on this monstrosity."
	hits = 30
	hitpwr = EXPLODE_DEVASTATE
	heavy = TRUE
	meteorsound = 'sound/effects/bamf.ogg'
	meteordrop = list(/obj/item/stack/ore/plasma)

/obj/effect/meteor/tunguska/Move()
	. = ..()
	if(.)
		new /obj/effect/temp_visual/revenant(get_turf(src))

/obj/effect/meteor/tunguska/meteor_effect()
	..()
	explosion(loc, 5, 10, 15, 20, 0, cause = "[name]: End explosion")

/obj/effect/meteor/tunguska/Bump()
	..()
	if(prob(20))
		explosion(loc, 2, 4, 6, 8, cause = "[name]: Bump explosion")

//Meaty Ore
/obj/effect/meteor/meaty
	name = "meaty ore"
	icon_state = "meateor"
	desc = "Just... don't think too hard about where this thing came from."
	hits = 2
	heavy = TRUE
	meteorsound = 'sound/effects/blobattack.ogg'
	meteordrop = list(/obj/item/food/meat/human, /obj/item/organ/internal/heart, /obj/item/organ/internal/lungs, /obj/item/organ/internal/appendix)
	var/meteorgibs = /obj/effect/gibspawner/generic

/obj/effect/meteor/meaty/make_debris()
	..()
	new meteorgibs(get_turf(src))


/obj/effect/meteor/meaty/ram_turf(turf/T)
	if(!isspaceturf(T))
		new /obj/effect/decal/cleanable/blood(T)

/obj/effect/meteor/meaty/Bump(atom/A)
	A.ex_act(hitpwr)
	get_hit()

//Meaty Ore Xeno edition
/obj/effect/meteor/meaty/xeno
	color = "#5EFF00"
	meteordrop = list(/obj/item/food/monstermeat/xenomeat)
	meteorgibs = /obj/effect/gibspawner/xeno

/obj/effect/meteor/meaty/xeno/Initialize(mapload, target)
	meteordrop += subtypesof(/obj/item/organ/internal/alien)
	return ..()

/obj/effect/meteor/meaty/xeno/ram_turf(turf/T)
	if(!isspaceturf(T))
		new /obj/effect/decal/cleanable/blood/xeno(T)

//////////////////////////
//Spookoween meteors
/////////////////////////

/obj/effect/meteor/pumpkin
	name = "PUMPKING"
	desc = "THE PUMPKING'S COMING!"
	icon = 'icons/obj/meteor_spooky.dmi'
	icon_state = "pumpkin"
	hits = 10
	heavy = TRUE
	dropamt = 1
	meteordrop = list(/obj/item/clothing/head/hardhat/pumpkinhead, /obj/item/food/grown/pumpkin)

/obj/effect/meteor/pumpkin/Initialize(mapload, target)
	. = ..()
	meteorsound = pick('sound/hallucinations/im_here1.ogg','sound/hallucinations/im_here2.ogg')

//////////////////////////
#undef DEFAULT_METEOR_LIFETIME
#undef MAP_EDGE_PAD
