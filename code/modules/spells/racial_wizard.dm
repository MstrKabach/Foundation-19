//this file is full of all the racial spells/artifacts/etc that each species has.

/obj/item/magic_rock
	name = "magical rock"
	desc = "Legends say that this rock will unlock the true potential of anyone who touches it."
	icon = 'icons/obj/wizard.dmi'
	icon_state = "magic rock"
	w_class = ITEM_SIZE_SMALL
	throw_speed = 1
	throw_range = 3
	force = 15
	var/list/potentials = list(
		SPECIES_HUMAN = /obj/item/storage/bag/cash/infinite,
		SPECIES_VOX = /datum/spell/targeted/shapeshift/true_form,
		SPECIES_UNATHI = /datum/spell/moghes_blessing,
		SPECIES_DIONA = /datum/spell/aoe_turf/conjure/grove/gestalt,
		SPECIES_SKRELL = /obj/item/contract/apprentice/skrell,
		SPECIES_IPC = /datum/spell/camera_connection)

/obj/item/magic_rock/attack_self(mob/user)
	if(!istype(user,/mob/living/carbon/human))
		to_chat(user, "\The [src] can do nothing for such a simple being.")
		return
	var/mob/living/carbon/human/H = user
	var/reward = potentials[H.species.get_bodytype(H)] //we get body type because that lets us ignore subspecies.
	if(!reward)
		to_chat(user, "\The [src] does not know what to make of you.")
		return
	for(var/datum/spell/S in user.mind.learned_spells)
		if(istype(S,reward))
			to_chat(user, "\The [src] can do no more for you.")
			return
	var/a = new reward()
	if(ispath(reward, /datum/spell))
		H.add_spell(a)
	else if(ispath(reward,/obj))
		H.put_in_hands(a)
	to_chat(user, "\The [src] crumbles in your hands.")
	qdel(src)

/obj/item/storage/bag/cash/infinite
	startswith = list(/obj/item/spacecash/bundle/c1000 = 1)

//HUMAN
/obj/item/storage/bag/cash/infinite/remove_from_storage(obj/item/W as obj, atom/new_location)
	. = ..()
	if(.)
		if(istype(W,/obj/item/spacecash)) //only matters if its spacecash.
			var/obj/item/I = new /obj/item/spacecash/bundle/c1000()
			src.handle_item_insertion(I,1)

/datum/spell/messa_shroud/choose_targets(user)
	var/list/targets = list(get_turf(holder))
	perform(user, targets)

/datum/spell/messa_shroud/cast(list/targets, mob/user)
	var/turf/T = targets[1]

	if(!istype(T))
		return

	var/obj/O = new /obj(T)
	O.set_light(-10, 0.1, 10, 2, "#ffffff")

	spawn(duration)
		qdel(O)

//VOX
/datum/spell/targeted/shapeshift/true_form
	name = "True Form"
	desc = "Pay respect to your heritage. Become what you once were."

	spell_flags = INCLUDEUSER
	invocation_type = INVOKE_EMOTE
	range = -1
	invocation = "begins to grow!"
	charge_max = 1200 //2 minutes
	duration = 300 //30 seconds

	smoke_amt = 5
	smoke_spread = 1

	possible_transformations = list(/mob/living/simple_animal/hostile/retaliate/parrot/space/lesser)

	hud_state = "wiz_vox"

	cast_sound = 'sounds/voice/shriek1.ogg'
	revert_sound = 'sounds/voice/shriek1.ogg'

	drop_items = 0


//UNATHI
/datum/spell/moghes_blessing
	name = "Moghes Blessing"
	desc = "Imbue your weapon with memories of Moghes."

	spell_flags = 0
	invocation_type = INVOKE_EMOTE
	invocation = "whispers something."
	charge_type = SPELL_HOLDVAR
	holder_var_type = "bruteloss"
	holder_var_amount = 10

	hud_state = "wiz_unathi"

/datum/spell/moghes_blessing/choose_targets(mob/user = usr)
	var/list/hands = list()
	for(var/obj/item/I in list(user.l_hand, user.r_hand))
		//make sure it's not already blessed
		if(istype(I) && !has_extension(I, /datum/extension/moghes_blessing))
			hands += I
	perform(user, hands)

/datum/spell/moghes_blessing/cast(list/targets, mob/user)
	for(var/obj/item/I in targets)
		set_extension(I, /datum/extension/moghes_blessing)

/datum/extension/moghes_blessing
	base_type = /datum/extension/moghes_blessing
	expected_type = /obj/item
	flags = EXTENSION_FLAG_IMMEDIATE

/datum/extension/moghes_blessing/New(datum/holder)
	..(holder)
	apply_blessing(holder)

/datum/extension/moghes_blessing/proc/apply_blessing(obj/item/I)
	I.name += " of Moghes"
	I.desc += "<BR>It has been imbued with the memories of Moghes."
	I.force += 10
	I.throwforce += 14
	I.color = "#663300"

//DIONA
/datum/spell/aoe_turf/conjure/grove/gestalt
	name = "Convert Gestalt"
	desc = "Converts the surrounding area into a diona gestalt."

	spell_flags = 0
	invocation_type = INVOKE_EMOTE
	invocation = "rumbles as strange alien growth quickly overtakes their surroundings."

	charge_type = SPELL_HOLDVAR
	holder_var_type = "bruteloss"
	holder_var_amount = 20

	spell_flags = Z2NOCAST | IGNOREPREV | IGNOREDENSE
	summon_type = list(/turf/simulated/floor/diona)
	seed_type = /datum/seed/diona

	hud_state = "wiz_diona"

//SKRELL
/obj/item/contract/apprentice/skrell
	name = "skrellian apprenticeship contract"
	var/obj/item/spellbook/linked
	color = "#3366ff"
	contract_spells = list(/datum/spell/contract/return_master) //somewhat of a necessity due to how many spells they would have after a while.

/obj/item/contract/apprentice/skrell/New(newloc,spellbook, owner)
	..()
	if(istype(spellbook,/obj/item/spellbook))
		linked = spellbook
	if(istype(owner,/mob))
		contract_master = owner

/obj/item/contract/apprentice/skrell/attack_self(mob/user as mob)
	if(!linked)
		to_chat(user, SPAN_WARNING("This contract requires a link to a spellbook."))
		return
	..()

/obj/item/contract/apprentice/skrell/afterattack(atom/A, mob/user as mob, proximity)
	if(!linked && istype(A,/obj/item/spellbook))
		linked = A
		to_chat(user, SPAN_NOTICE("You've linked \the [A] to \the [src]"))
		return
	..()

/obj/item/contract/apprentice/skrell/contract_effect(mob/user as mob)
	. = ..()
	if(.)
		var/obj/item/I = new /obj/item/contract/apprentice/skrell(get_turf(src),linked,contract_master)
		user.put_in_hands(I)
		new /obj/item/contract/apprentice/skrell(get_turf(src),linked,contract_master)

//IPC
/datum/spell/camera_connection
	name = "Camera Connection"
	desc = "This spell allows the wizard to connect to the local camera network and see what it sees."

	invocation_type = INVOKE_EMOTE
	invocation = "emits a beeping sound before standing very, very still."

	charge_max = 600 //1 minute
	charge_type = SPELL_RECHARGE


	spell_flags = Z2NOCAST
	hud_state = "wiz_IPC"
	var/mob/observer/eye/vision
	var/eye_type = /mob/observer/eye/wizard_eye

/datum/spell/camera_connection/New()
	..()
	vision = new eye_type(src)

/datum/spell/camera_connection/Destroy()
	qdel(vision)
	vision = null
	. = ..()

/datum/spell/camera_connection/choose_targets(user = usr)
	var/mob/living/L = holder
	if(!istype(L) || L.eyeobj) //no using if we already have an eye on.
		return null
	perform(user, list(holder))

/datum/spell/camera_connection/cast(list/targets, mob/user)
	var/mob/living/L = targets[1]

	vision.possess(L)
	GLOB.destroyed_event.register(L, src, TYPE_PROC_REF(/datum/spell/camera_connection, release))
	GLOB.logged_out_event.register(L, src, TYPE_PROC_REF(/datum/spell/camera_connection, release))
	add_verb(L, /mob/living/proc/release_eye)

/datum/spell/camera_connection/proc/release(mob/living/L)
	vision.release(L)
	remove_verb(L, /mob/living/proc/release_eye)
	GLOB.destroyed_event.unregister(L, src)
	GLOB.logged_out_event.unregister(L, src)

/mob/observer/eye/wizard_eye
	name_sufix = "Wizard Eye"

/mob/observer/eye/wizard_eye/New() //we dont use the Ai one because it has AI specific procs imbedded in it.
	..()
	visualnet = cameranet

/mob/living/proc/release_eye()
	set name = "Release Vision"
	set desc = "Return your sight to your body."
	set category = "Abilities"

	remove_verb(src, /mob/living/proc/release_eye) //regardless of if we have an eye or not we want to get rid of this verb.

	if(!eyeobj)
		return
	eyeobj.release(src)

/mob/observer/eye/wizard_eye/Destroy()
	if(istype(eyeobj.owner, /mob/living))
		var/mob/living/L = eyeobj.owner
		L.release_eye()
	qdel(eyeobj)
	return ..()
