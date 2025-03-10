/////////////////////////////////////////
//Standard Rings
/obj/item/clothing/ring/engagement
	name = "engagement ring"
	desc = "An engagement ring. It certainly looks expensive."
	icon_state = "diamond"

/obj/item/clothing/ring/engagement/attack_self(mob/user)
	user.visible_message(SPAN_WARNING("\The [user] gets down on one knee, presenting \the [src]."),SPAN_WARNING("You get down on one knee, presenting \the [src]."))

/obj/item/clothing/ring/fleet
	name = "Fleet ring"
	desc = "A ring commemorating honorable service with the Sol Government's Fleet."
	icon_state = "fleet"

/obj/item/clothing/ring/ec
	name = "Expeditionary Corps ring"
	desc = "A ring commemorating honorable service with the Sol Government's Expeditionary Corps."
	icon_state = "ec"

/////////////////////////////////////////
//Magic Rings

/obj/item/clothing/ring/magic
	name = "magic ring"
	desc = "A strange ring with symbols carved on it in some arcane language."
	icon_state = "magic"

/obj/item/clothing/ring/magic/equipped(mob/living/carbon/human/H, slot)
	..()
	if(istype(H) && slot == SLOT_GLOVES)
		H.add_cloaking_source(src)

/obj/item/clothing/ring/magic/dropped(mob/living/carbon/human/H)
	if(!..())
		return 0

	if(istype(H))
		H.remove_cloaking_source(src)

/////////////////////////////////////////
//Reagent Rings

/obj/item/clothing/ring/reagent
	atom_flags = ATOM_FLAG_OPEN_CONTAINER
	origin_tech = list(TECH_MATERIAL = 2, TECH_ESOTERIC = 4)

/obj/item/clothing/ring/reagent/New()
	..()
	create_reagents(15)

/obj/item/clothing/ring/reagent/equipped(mob/living/carbon/human/H)
	..()
	if(istype(H) && H.gloves==src)
		to_chat(H, SPAN_INFO("<b>You feel a prick as you slip on the ring.</b>"))

		if(reagents.total_volume)
			if(H.reagents)
				var/should_admin_log = reagents.should_admin_log()
				var/contained_reagents = reagents.get_reagents()
				var/trans = reagents.trans_to_mob(H, 15, CHEM_BLOOD)
				if (should_admin_log)
					admin_inject_log(usr, H, src, contained_reagents, trans)
	return

//Sleepy Ring
/obj/item/clothing/ring/reagent/sleepy
	name = "silver ring"
	desc = "A ring made from what appears to be silver."
	icon_state = "material"
	origin_tech = list(TECH_MATERIAL = 2, TECH_ESOTERIC = 5)

/obj/item/clothing/ring/reagent/sleepy/New()
	..()
	reagents.add_reagent(/datum/reagent/chloral_hydrate, 15) // Less than a sleepy-pen, but still enough to knock someone out

/////////////////////////////////////////
//Seals and Signet Rings

/obj/item/clothing/ring/seal/
	icon = 'icons/obj/clothing/obj_hands_ring.dmi'

/obj/item/clothing/ring/seal/secgen
	name = "Secretary-General's official seal"
	desc = "The official seal of the Secretary-General of the Sol Central Government, featured prominently on a silver ring."
	icon_state = "seal-secgen"

/obj/item/clothing/ring/seal/mason
	name = "masonic ring"
	desc = "The Square and Compasses feature prominently on this Masonic ring."
	icon_state = "seal-masonic"

/obj/item/clothing/ring/seal/signet
	name = "signet ring"
	desc = "A signet ring, for when you're too sophisticated to sign letters."
	icon_state = "seal-signet"
	var/nameset = 0

/obj/item/clothing/ring/seal/signet/attack_self(mob/user)
	if(nameset)
		to_chat(user, SPAN_NOTICE("The [src] has already been claimed!"))
		return

	nameset = 1
	to_chat(user, SPAN_NOTICE("You claim the [src] as your own!"))
	name = "[user]'s signet ring"
	desc = "A signet ring belonging to [user], for when you're too sophisticated to sign letters."
