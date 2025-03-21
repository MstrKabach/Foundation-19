/mob/living/silicon/robot/syndicate
	lawupdate = FALSE
	scrambledcodes = TRUE
	icon_state = "securityrobot"
	modtype = "Security"
	lawchannel = "State"
	laws = /datum/ai_laws/insurgency_override
	idcard = /obj/item/card/id/syndicate
	module = /obj/item/robot_module/syndicate
	silicon_radio = /obj/item/device/radio/borg/syndicate
	spawn_sound = 'sounds/mecha/nominalsyndi.ogg'
	cell = /obj/item/cell/super
	pitch_toggle = FALSE

/mob/living/silicon/robot/combat/isd
	lawupdate = FALSE
	scrambledcodes = TRUE
	modtype = "Internal Security"
	module = /obj/item/robot_module/special/general
	spawn_sound = 'sounds/mecha/nominalsyndi.ogg'
	cell = /obj/item/cell/infinite
	pitch_toggle = FALSE

/mob/living/silicon/robot/combat
	lawupdate = FALSE
	scrambledcodes = TRUE
	modtype = "Combat"
	module = /obj/item/robot_module/security/combat
	spawn_sound = 'sounds/mecha/nominalsyndi.ogg'
	cell = /obj/item/cell/super
	pitch_toggle = FALSE

/mob/living/silicon/robot/combat/foundation
	laws = /datum/ai_laws/foundation_aggressive
	idcard = /obj/item/card/id/centcom/ERT
	silicon_radio = /obj/item/device/radio/borg/ert

/mob/living/silicon/robot/flying/ascent
	desc = "A small, sleek, dangerous-looking hover-drone."
	speak_statement = "clicks"
	speak_exclamation = "rasps"
	speak_query = "chirps"
	lawupdate = FALSE
	scrambledcodes = TRUE
	speed = -2
	icon_state = "drone-ascent"
	spawn_sound = 'sounds/voice/ascent1.ogg'
	cell =   /obj/item/cell/mantid
//	laws =   /datum/ai_laws/ascent
	idcard = /obj/item/card/id/ascent
	module = /obj/item/robot_module/flying/ascent
	req_access = list(ACCESS_ASCENT)
	silicon_radio = null
	machine_restriction = FALSE
	faction = "kharmaani"
	var/global/ascent_drone_count = 0

/mob/living/silicon/robot/flying/ascent/add_ion_law(law)
	return FALSE

/mob/living/silicon/robot/flying/ascent/Initialize()
	. = ..()
	remove_language(LANGUAGE_ENGLISH)
	remove_language(LANGUAGE_EAL)
	remove_language(LANGUAGE_ROBOT_GLOBAL)
	default_language = all_languages[LANGUAGE_MANTID_NONVOCAL]

/mob/living/silicon/robot/flying/ascent/examine(mob/user)
	. = ..()
	if(ishuman(user))
		var/mob/living/carbon/human/H = user
		if(H.species.name == SPECIES_SKRELL) // TODO make codex searches able to check the reader's species.
			to_chat(H, SPAN_NOTICE("You recognize it as a product of the warlike, insectoid Ascent, long-time rivals to your people."))
			return
	to_chat(user, SPAN_NOTICE("The design is clearly not of human manufacture."))

/mob/living/silicon/robot/flying/ascent/initialize_components()
	components["actuator"] =       new/datum/robot_component/actuator/ascent(src)
	components["power cell"] =     new/datum/robot_component/cell/ascent(src)
	components["diagnosis unit"] = new/datum/robot_component/diagnosis_unit(src)
	components["armour"] =         new/datum/robot_component/armour/light(src)

/mob/living/silicon/robot/flying/ascent/law_channels()
	var/list/channels = new()
	channels += additional_law_channels
	channels += LANGUAGE_MANTID_BROADCAST
	return channels

/mob/living/silicon/robot/flying/ascent/statelaws(datum/ai_laws/laws)
	var/prefix = ""
	if (lawchannel == LANGUAGE_MANTID_BROADCAST)
		prefix = "[get_language_prefix()]\["

	if (prefix)
		dostatelaws(lawchannel, prefix, laws)
	else
		..()


// Since they don't have binary, camera or radio to soak
// damage, they get some hefty buffs to cell and actuator.
/datum/robot_component/actuator/ascent
	max_damage = 100
/datum/robot_component/cell/ascent
	max_damage = 100

/mob/living/silicon/robot/flying/ascent/Initialize()
	. = ..()
	name = "Strange Cyborg [rand(0, 500)]"

// Sorry, you're going to have to actually deal with these guys.
/mob/living/silicon/robot/flying/ascent/flash_eyes(intensity = FLASH_PROTECTION_MODERATE, override_blindness_check = FALSE, affect_silicon = FALSE, visual = FALSE, type = /obj/screen/fullscreen/flash)
	emp_act(2)

/mob/living/silicon/robot/flying/ascent/emp_act(severity)
	confused = min(confused + rand(3, 5), (severity == 1 ? 40 : 30))
