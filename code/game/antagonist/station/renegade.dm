GLOBAL_DATUM_INIT(renegades, /datum/antagonist/renegade, new)

/datum/antagonist/renegade
	role_text = "Renegade"
	role_text_plural = "Renegades"
	blacklisted_jobs = list(/datum/job/ai, /datum/job/classd, /datum/job/captain, /datum/job/hos, /datum/job/rd, /datum/job/ethicsliaison, /datum/job/tribunal, /datum/job/commsofficer, /datum/job/enlistedofficerez, /datum/job/enlistedofficerlcz, /datum/job/enlistedofficerhcz, /datum/job/ncoofficerez, /datum/job/ncoofficerlcz, /datum/job/ncoofficerhcz, /datum/job/ltofficerez, /datum/job/ltofficerlcz, /datum/job/ltofficerhcz, /datum/job/goirep, /datum/job/raisa)
//	restricted_jobs = list(/datum/job/officer, /datum/job/warden, /datum/job/captain, /datum/job/hop, /datum/job/hos, /datum/job/chief_engineer, /datum/job/rd, /datum/job/cmo)
	welcome_text = "Something's going to go wrong today, you can just feel it. You're paranoid, you've got a gun, and you're going to survive."
	antag_text = "You are a <b>minor</b> antagonist! Within the rules, \
		try to protect yourself and what's important to you. You aren't here to <i>cause</i> trouble, \
		you're just willing (and equipped) to go to extremes to <b>stop</b> it. \
		Your job is to oppose the other antagonists, should they threaten you, in ways that aren't quite legal. \
		Try to make sure other players have <i>fun</i>! If you are confused or at a loss, always adminhelp, \
		and before taking extreme actions, please try to also contact the administration! \
		Think through your actions and make the roleplay immersive! <b>Please remember all \
		rules aside from those without explicit exceptions apply to antagonists.</b>"

	id = MODE_RENEGADE
	flags = ANTAG_SUSPICIOUS | ANTAG_IMPLANT_IMMUNE | ANTAG_RANDSPAWN | ANTAG_VOTABLE
	hard_cap = 3
	hard_cap_round = 5

	initial_spawn_req = 1
	initial_spawn_target = 3
	antaghud_indicator = "hud_renegade"
	skill_setter = /datum/antag_skill_setter/station

	var/list/spawn_guns = list(
		/obj/item/gun/energy/retro,
		/obj/item/gun/energy/gun,
		/obj/item/gun/energy/crossbow,
		/obj/item/gun/energy/pulse_rifle/pistol,
		/obj/item/gun/projectile/automatic,
		/obj/item/gun/projectile/automatic/machine_pistol,
		/obj/item/gun/projectile/automatic/sec_smg,
		/obj/item/gun/projectile/pistol/magnum_pistol,
		/obj/item/gun/projectile/pistol/military,
		/obj/item/gun/projectile/pistol/military/alt,
		/obj/item/gun/projectile/pistol/sec/lethal,
		/obj/item/gun/projectile/pistol/holdout,
		/obj/item/gun/projectile/revolver,
		/obj/item/gun/projectile/revolver/medium,
		/obj/item/gun/projectile/shotgun/doublebarrel/sawn,
		/obj/item/gun/projectile/pistol/magnum_pistol,
		/obj/item/gun/projectile/revolver/holdout,
		/obj/item/gun/projectile/pistol/throwback,
		/obj/item/gun/energy/xray/pistol,
		/obj/item/gun/energy/toxgun,
		/obj/item/gun/energy/incendiary_laser,
		/obj/item/gun/projectile/pistol/magnum_pistol
		)

/datum/antagonist/renegade/create_objectives(datum/mind/player)

	if(!..())
		return

	var/datum/objective/survive/survive = new
	survive.owner = player
	player.objectives |= survive

/datum/antagonist/renegade/equip(mob/living/carbon/human/player)

	if(!..())
		return

	var/gun_type = pick(spawn_guns)
	if(islist(gun_type))
		gun_type = pick(gun_type)
	var/obj/item/gun = new gun_type(get_turf(player))

	// Attempt to put into a container.
	if(player.equip_to_storage(gun))
		return

	// If that failed, attempt to put into any valid non-handslot
	if(player.equip_to_appropriate_slot(gun))
		return

	// If that failed, then finally attempt to at least let the player carry the weapon
	player.put_in_hands(gun)


/proc/rightandwrong()
	to_chat(usr, "<B>You summoned guns!</B>")
	message_staff("[key_name_admin(usr, 1)] summoned guns!")
	for(var/mob/living/carbon/human/H in GLOB.player_list)
		if(H.stat == 2 || !(H.client)) continue
		if(is_special_character(H)) continue
		GLOB.renegades.add_antagonist(H.mind)
