// large amount of fields creates a heavy load on the server, see updateinfolinks() and addtofield()
#define MAX_FIELDS 50

#define PAPER_CAMERA_DISTANCE 2
#define PAPER_EYEBALL_DISTANCE 3

#define PAPER_META(message) "<p><i>[message]</i></p>"
#define PAPER_META_BAD(message) "<p style='color:red'><i>[message]</i></p>"

/*
 * Paper
 * also scraps of paper
 */

/obj/item/paper
	name = "sheet of paper"
	gender = NEUTER
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper"
	item_state = "paper"
	randpixel = 8
	throwforce = 0
	w_class = ITEM_SIZE_TINY
	throw_range = 1
	throw_speed = 1
	layer = ABOVE_OBJ_LAYER
	slot_flags = SLOT_HEAD
	body_parts_covered = HEAD
	attack_verb = list("bapped")

	var/info		//What's actually written on the paper.
	var/info_links	//A different version of the paper which includes html links at fields and EOF
	var/stamps		//The (text for the) stamps on the paper.
	var/fields		//Amount of user created fields
	var/free_space = MAX_PAPER_MESSAGE_LEN
	var/list/stamped
	var/list/ico[0]      //Icons and
	var/list/offset_x[0] //offsets stored for later
	var/list/offset_y[0] //usage by the photocopier
	var/spam_flag = 0
	var/last_modified_ckey
	var/age = 0
	var/list/metadata
	var/readable = TRUE  //Paper will not be able to be written on and will not bring up a window upon examine if FALSE
	var/is_memo = FALSE  //If TRUE, paper will act the same as readable = FALSE, but will also be unrenameable.
	var/datum/language/language = LANGUAGE_ENGLISH // Language the paper was written in. Editable by users up until something's actually written

	///Whether or not title should be show in the desc.
	var/show_title = TRUE

	var/const/deffont = "Verdana"
	var/const/signfont = "Times New Roman"
	var/const/crayonfont = "Comic Sans MS"
	var/const/fancyfont = "Segoe Script"

	var/scan_file_type = /datum/computer_file/data/text

/obj/item/paper/New(loc, text, title, list/md = null, datum/language/L = null)
	if (L)
		language = L
	. = ..(loc)
	set_content(text ? text : info, title)
	metadata = md

/obj/item/paper/Initialize(mapload)
	. = ..(mapload)
	var/old_language = language
	if (!set_language(language, TRUE))
		log_debug("[src] ([type]) initialized with invalid or missing language `[old_language]` defined.")
		set_language(LANGUAGE_ENGLISH, TRUE)

/obj/item/paper/proc/set_content(text,title)
	if(title)
		SetName(title)
	info = html_encode(text)
	info = parsepencode(text)
	update_icon()
	update_space(info)
	updateinfolinks()

/obj/item/paper/proc/set_language(datum/language/new_language, force = FALSE)
	if (!new_language || (info && !force))
		return FALSE

	if (!istype(new_language))
		new_language = global.all_languages[new_language]
	if (!istype(new_language))
		return FALSE

	language = new_language
	return TRUE

/obj/item/paper/on_update_icon()
	if(icon_state == "paper_talisman" || is_memo)
		return
	else if(info)
		icon_state = "paper_words"
	else
		icon_state = "paper"

/obj/item/paper/proc/update_space(new_text)
	if(new_text)
		free_space -= length(strip_html_properly(new_text))

/obj/item/paper/examine(mob/user, distance)
	. = ..()
	if(!is_memo && name != "sheet of paper" && show_title)
		to_chat(user, "It's titled '[name]'.")
	if(distance <= 1)
		show_content(usr)
	else
		to_chat(user, SPAN_NOTICE("You have to go closer if you want to read it."))

/obj/item/paper/verb/user_set_language()
	set name = "Set writing language"
	set category = "Object"
	set src in usr

	choose_language(usr)

/obj/item/paper/proc/choose_language(mob/user, admin_force = FALSE)
	if (info)
		to_chat(user, SPAN_WARNING("\The [src] already has writing on it and cannot have its language changed."))
		return
	if (!admin_force && !user.languages.len)
		to_chat(user, SPAN_WARNING("You don't know any languages to choose from."))
		return

	var/list/selectable_languages = list()
	if (admin_force)
		for (var/key in global.all_languages)
			var/datum/language/L = global.all_languages[key]
			if (L.has_written_form)
				selectable_languages += L
	else
		for (var/datum/language/L in user.languages)
			if (L.has_written_form)
				selectable_languages += L

	var/new_language = input(user, "What language do you want to write in?", "Change language", language) as null|anything in selectable_languages
	if (!new_language || new_language == language)
		to_chat(user, SPAN_NOTICE("You decide to leave the language as [language.name]."))
		return
	if (!admin_force && !Adjacent(user) && !CanInteract(user, GLOB.deep_inventory_state))
		to_chat(user, SPAN_WARNING("You must remain next to or continue holding \the [src] to do that."))
		return
	set_language(new_language)


/obj/item/paper/proc/show_content(mob/user, force, editable)
	if (!readable || is_memo)
		return
	if (isclient(user))
		var/client/C = user
		user = C.mob
	if (!user)
		return
	var/can_read = force || isghost(user)
	if (!can_read)
		can_read = isAI(user)
		if (can_read)
			var/mob/living/silicon/ai/AI = user
			can_read = get_dist(src, AI.camera) < PAPER_CAMERA_DISTANCE
		else
			can_read = ishuman(user) || issilicon(user)
			if (can_read)
				can_read = get_dist(src, user) < PAPER_EYEBALL_DISTANCE
	var/html = "<meta http-equiv='X-UA-Compatible' content='IE=edge' charset='UTF-8'/>"
	if (!can_read)
		html += PAPER_META_BAD("The paper is too far away or you can't read.")
	var/has_content = length(info)
	var/has_language = force || (language in user.languages)
	if (has_content && !has_language && !isghost(user))
		html += PAPER_META_BAD("The paper is written in a language you don't understand.")
		html += "<hr/>" + language.scramble(info)
	else if (editable)
		if (has_content)
			html += PAPER_META("The paper is written in [language.name].")
			html += "<hr/>" + info_links
		else if (force || length(user.languages))
			if (!has_language)
				language = user.languages[1]
			html += PAPER_META("You are writing in <a href='?src=\ref[src];change_language=1'>[language.name]</a>.")
			html += "<hr/>" + info_links
		else
			html += PAPER_META_BAD("You can't write without knowing a language.")
	else if (has_content)
		html += PAPER_META("The paper is written in [language.name].")
		html += "<hr/>" + info
	html += "[stamps]"

	// Ported to browser datum for IE11 feature parity
	var/datum/browser/window = new(user, "paper_[name]")
	window.stylesheets.Remove("common")
	window.add_stylesheet("acs", 'html/acs.css')
	window.add_head_content("<title>[name]</title><style>body { background-color: [color]; }</style>")
	window.set_content(html)
	window.open()

	if(isnull(name))
		crash_with("Paper failed a sanity check. It has no name. Report that! | Type: [type]")

/obj/item/paper/verb/rename()
	set name = "Rename paper"
	set category = "Object"
	set src in usr

	if((MUTATION_CLUMSY in usr.mutations) && prob(50))
		to_chat(usr, SPAN_WARNING("You cut yourself on the paper."))
		return
	else if(is_memo)
		to_chat(usr, SPAN_NOTICE("You decide not to alter the name of \the [src]."))
		return
	var/n_name = sanitizeSafe(input(usr, "What would you like to label the paper?", "Paper Labelling", null)  as text, MAX_NAME_LEN)

	// We check loc one level up, so we can rename in clipboards and such. See also: /obj/item/photo/rename()
	if(!n_name || !CanInteract(usr, GLOB.deep_inventory_state))
		return
	SetName(n_name)
	add_fingerprint(usr)

/obj/item/paper/attack_self(mob/living/user as mob)
	if(user.a_intent == I_HURT)
		if(icon_state == "scrap")
			user.show_message(SPAN_WARNING("\The [src] is already crumpled."))
			return
		//crumple dat paper
		info = stars(info,85)
		user.visible_message("\The [user] crumples \the [src] into a ball!")
		icon_state = "scrap"
		return
	user.examinate(src)

/obj/item/paper/attack_ai(mob/living/silicon/ai/user)
	show_content(user)

/obj/item/paper/attack(mob/living/carbon/M, mob/living/carbon/user)
	if (user.zone_sel.selecting == BP_EYES)
		user.visible_message(
			SPAN_NOTICE("You show \the [src] to \the [M]. "), \
			SPAN_NOTICE("\The [user] holds up \the [src] and shows it to \the [M].")
		)
		M.examinate(src)

	else if (ishuman(M)) // check human-specific interactions
		var/mob/living/carbon/human/H = M

		if (user.zone_sel.selecting == BP_MOUTH) // lipstick wiping
			if (H == user)
				user.visible_message(
					SPAN_NOTICE("\The [user] wipes off \his lipstick."),
					SPAN_NOTICE("You wipe off your lipstick.")
				)
				H.lip_style = null
				H.update_body()
			else
				user.visible_message(
					SPAN_WARNING("\The [user] begins to wipe \the [H]'s lipstick off with \the [src]."), \
					SPAN_NOTICE("You begin to wipe off \the [H]'s lipstick.")
				)
				if (do_after(user, 2 SECONDS, H, do_flags = DO_DEFAULT & ~DO_BOTH_CAN_TURN))
					user.visible_message(
						SPAN_NOTICE("\The [user] wipes \the [H]'s lipstick off with \the [src]."), \
						SPAN_NOTICE("You wipe off \the [H]'s lipstick.")
					)
					H.lip_style = null
					H.update_body()

		else if (user.zone_sel.selecting == BP_HEAD) // graffiti wiping
			var/obj/item/organ/external/head/head = H.organs_by_name[BP_HEAD]
			if (!istype(head) || !head.forehead_graffiti)
				return
			if (H == user)
				user.visible_message(
					SPAN_NOTICE("\The [user] cleans the graffiti off of \his forehead."),
					SPAN_NOTICE("You clean off your forehead.")
				)
				head.forehead_graffiti = null
				head.graffiti_style = null
			else
				user.visible_message(
					SPAN_NOTICE("\The [user] starts cleaning \the [H]'s forehead with \the [src]."),
					SPAN_NOTICE("You start wiping the graffiti off of \the [H]'s forehead.")
				)
				if (!do_after(user, 2 SECONDS, H, do_flags = DO_DEFAULT & ~DO_BOTH_CAN_TURN) || !head?.forehead_graffiti)
					return
				user.visible_message(
					SPAN_NOTICE("\The [user] wipes the graffiti off of \the [H]'s forehead."),
					SPAN_NOTICE("You wipe the graffiti off of \the [H]'s forehead.")
				)
				head.forehead_graffiti = null
				head.graffiti_style = null

/obj/item/paper/proc/addtofield(id, text, links = 0)
	var/locid = 0
	var/laststart = 1
	var/textindex = 1
	while(locid < MAX_FIELDS)
		var/istart = 0
		if(links)
			istart = findtext(info_links, "<span class=\"paper_field\">", laststart)
		else
			istart = findtext(info, "<span class=\"paper_field\">", laststart)

		if(istart==0)
			return // No field found with matching id

		laststart = istart+1
		locid++
		if(locid == id)
			var/iend = 1
			if(links)
				iend = findtext(info_links, "</span>", istart)
			else
				iend = findtext(info, "</span>", istart)

			textindex = iend
			break

	if(links)
		var/before = copytext(info_links, 1, textindex)
		var/after = copytext(info_links, textindex)
		info_links = before + text + after
	else
		var/before = copytext(info, 1, textindex)
		var/after = copytext(info, textindex)
		info = before + text + after
		updateinfolinks()

/obj/item/paper/proc/updateinfolinks()
	info_links = info
	var/i = 0
	for(i=1,i<=fields,i++)
		addtofield(i, "<font face=\"[deffont]\"><A href='?src=\ref[src];write=[i]'>write</A></font>", 1)
	info_links = info_links + "<font face=\"[deffont]\"><A href='?src=\ref[src];write=end'>write</A></font>"


/obj/item/paper/proc/clearpaper()
	info = null
	stamps = null
	free_space = MAX_PAPER_MESSAGE_LEN
	stamped = list()
	cut_overlays()
	updateinfolinks()
	update_icon()

/obj/item/paper/proc/get_signature(obj/item/pen/P, mob/user as mob)
	if(P && istype(P, /obj/item/pen))
		return P.get_signature(user)
	return (user && user.real_name) ? user.real_name : "Anonymous"

/obj/item/paper/proc/parsepencode(t, obj/item/pen/P, mob/user, iscrayon, isfancy)
	if(length(t) == 0)
		return ""

	if(findtext(t, "\[sign\]"))
		t = replacetext(t, "\[sign\]", "<font face=\"[signfont]\"><i>[get_signature(P, user)]</i></font>")

	if(iscrayon) // If it is a crayon, and he still tries to use these, make them empty!
		t = replacetext(t, "\[*\]", "")
		t = replacetext(t, "\[hr\]", "")
		t = replacetext(t, "\[small\]", "")
		t = replacetext(t, "\[/small\]", "")
		t = replacetext(t, "\[list\]", "")
		t = replacetext(t, "\[/list\]", "")
		t = replacetext(t, "\[ulist\]", "")
		t = replacetext(t, "\[/ulist\]", "")
		t = replacetext(t, "\[olist\]", "")
		t = replacetext(t, "\[/olist\]", "")
		t = replacetext(t, "\[table\]", "")
		t = replacetext(t, "\[/table\]", "")
		t = replacetext(t, "\[row\]", "")
		t = replacetext(t, "\[cell\]", "")
		t = replacetext(t, "\[logo\]", "")

	if(iscrayon)
		t = "<font face=\"[crayonfont]\" color=[P ? P.colour : "black"]><b>[t]</b></font>"
	else if(isfancy)
		t = "<font face=\"[fancyfont]\" color=[P ? P.colour : "black"]><i>[t]</i></font>"
	else
		t = "<font face=\"[deffont]\" color=[P ? P.colour : "black"]>[t]</font>"

	t = pencode2html(t)

	//Count the fields
	var/laststart = 1
	while(fields < MAX_FIELDS)
		var/i = findtext(t, "<span class=\"paper_field\">", laststart)	//</span>
		if(i==0)
			break
		laststart = i+1
		fields++

	return t


/obj/item/paper/proc/burnpaper(obj/item/flame/P, mob/user)
	var/class = "warning"

	if(P.lit && !user.restrained())
		if(istype(P, /obj/item/flame/lighter/zippo))
			class = "rose"

		user.visible_message(SPAN_CLASS("[class]","[user] holds \the [P] up to \the [src], it looks like \he's trying to burn it!"), \
		SPAN_CLASS("[class]","You hold \the [P] up to \the [src], burning it slowly."))

		spawn(20)
			if(get_dist(src, user) < 2 && user.get_active_hand() == P && P.lit)
				user.visible_message(SPAN_CLASS("[class]","[user] burns right through \the [src], turning it to ash. It flutters through the air before settling on the floor in a heap."), \
				SPAN_CLASS("[class]","You burn right through \the [src], turning it to ash. It flutters through the air before settling on the floor in a heap."))

				new /obj/effect/decal/cleanable/ash(get_turf(src))
				qdel(src)

			else
				to_chat(user, SPAN_WARNING("You must hold \the [P] steady to burn \the [src]."))


/obj/item/paper/Topic(href, href_list)
	..()
	if(!usr || (usr.stat || usr.restrained()))
		return

	if (href_list["change_language"])
		choose_language(usr)
		show_content(usr, editable = TRUE)
		return

	if(href_list["write"])
		var/id = href_list["write"]
		//var/t = strip_html_simple(input(usr, "What text do you wish to add to " + (id=="end" ? "the end of the paper" : "field "+id) + "?", "[name]", null),8192) as message

		if(free_space <= 0)
			to_chat(usr, SPAN_INFO("There isn't enough space left on \the [src] to write anything."))
			return

		var/obj/item/I = usr.get_active_hand() // Check to see if he still got that darn pen, also check what type of pen
		var/iscrayon = 0
		var/isfancy = 0
		if(!istype(I, /obj/item/pen))
			if(usr.back && istype(usr.back,/obj/item/rig))
				var/obj/item/rig/r = usr.back
				var/obj/item/rig_module/device/pen/m = locate(/obj/item/rig_module/device/pen) in r.installed_modules
				if(!r.offline && m)
					I = m.device
				else
					return
			else
				return

		var/obj/item/pen/P = I
		if(!P.active)
			P.toggle()

		if(P.iscrayon)
			iscrayon = TRUE

		if(P.isfancy)
			isfancy = TRUE

		var/t =  sanitize(input("Enter what you want to write:", "Write", null, null) as message, free_space, extra = 0, trim = 0)

		if(!t)
			return

		// if paper is not in usr, then it must be near them, or in a clipboard or folder, which must be in or near usr
		if(src.loc != usr && !src.Adjacent(usr) && !((istype(src.loc, /obj/item/material/clipboard) || istype(src.loc, /obj/item/folder)) && (src.loc.loc == usr || src.loc.Adjacent(usr)) ) )
			return

		var/last_fields_value = fields

		t = parsepencode(t, I, usr, iscrayon, isfancy) // Encode everything from pencode to html


		if(fields > MAX_FIELDS)
			to_chat(usr, SPAN_WARNING("Too many fields. Sorry, you can't do this."))
			fields = last_fields_value
			return

		if(id!="end")
			addtofield(text2num(id), t) // He wants to edit a field, let him.
		else
			info += t // Oh, he wants to edit to the end of the file, let him.
			updateinfolinks()

		last_modified_ckey = usr.ckey

		update_space(t)

		show_content(usr, editable = TRUE)

		playsound(src, pick('sounds/effects/pen1.ogg','sounds/effects/pen2.ogg'), 10)
		update_icon()


/obj/item/paper/attackby(obj/item/P as obj, mob/user as mob)
	..()
	var/clown = 0
	if(user.mind && (user.mind.assigned_role == "Clown"))
		clown = 1

	if(istype(P, /obj/item/tape_roll))
		var/obj/item/tape_roll/tape = P
		tape.stick(src, user)
		return

	if(istype(P, /obj/item/paper) || istype(P, /obj/item/photo))
		if(!can_bundle())
			return
		var/obj/item/paper/other = P
		if(istype(other) && !other.can_bundle())
			return
		if (istype(P, /obj/item/paper/carbon))
			var/obj/item/paper/carbon/C = P
			if (!C.iscopy && !C.copied)
				to_chat(user, SPAN_NOTICE("Take off the carbon copy first."))
				add_fingerprint(user)
				return
		var/obj/item/paper_bundle/B = new(src.loc)
		if (name != "paper")
			B.SetName(name)
		else if (P.name != "paper" && P.name != "photo")
			B.SetName(P.name)

		if(!user.unEquip(P, B) || !user.unEquip(src, B))
			return
		user.put_in_hands(B)

		to_chat(user, SPAN_NOTICE("You clip the [P.name] to [(src.name == "paper") ? "the paper" : src.name]."))

		B.pages.Add(src)
		B.pages.Add(P)
		B.update_icon()

	else if(istype(P, /obj/item/pen))
		if(icon_state == "scrap")
			to_chat(usr, SPAN_WARNING("\The [src] is too crumpled to write on."))
			return

		var/obj/item/pen/robopen/RP = P
		if ( istype(RP) && RP.mode == 2 )
			RP.RenamePaper(user,src)
		else
			show_content(user, editable = TRUE)
		return

	else if(istype(P, /obj/item/stamp) || istype(P, /obj/item/clothing/ring/seal))
		if((!in_range(src, usr) && loc != user && !( istype(loc, /obj/item/material/clipboard) ) && loc.loc != user && user.get_active_hand() != P))
			return

		stamps += (stamps=="" ? "<HR>" : "<BR>") + "<i>This paper has been stamped with the [P.name].</i>"

		var/image/stampoverlay = image('icons/obj/bureaucracy.dmi')
		var/x
		var/y
		if(istype(P, /obj/item/stamp/captain) || istype(P, /obj/item/stamp/boss))
			x = rand(-2, 0)
			y = rand(-1, 2)
		else
			x = rand(-2, 2)
			y = rand(-3, 2)
		offset_x += x
		offset_y += y
		stampoverlay.pixel_x = x
		stampoverlay.pixel_y = y

		if(istype(P, /obj/item/stamp/clown))
			if(!clown)
				to_chat(user, SPAN_NOTICE("You are totally unable to use the stamp. HONK!"))
				return

		if(!ico)
			ico = new
		ico += "paper_[P.icon_state]"
		stampoverlay.icon_state = "paper_[P.icon_state]"

		if(!stamped)
			stamped = new
		stamped += P.type
		add_overlay(stampoverlay)

		playsound(src, 'sounds/effects/stamp.ogg', 50, 1)
		to_chat(user, SPAN_NOTICE("You stamp the paper with your [P.name]."))

	else if(istype(P, /obj/item/flame))
		burnpaper(P, user)

	else if(istype(P, /obj/item/paper_bundle))
		if(!can_bundle())
			return
		var/obj/item/paper_bundle/attacking_bundle = P
		attacking_bundle.insert_sheet_at(user, (attacking_bundle.pages.len)+1, src)
		attacking_bundle.update_icon()

	add_fingerprint(user)

/obj/item/paper/proc/can_bundle()
	return TRUE

/obj/item/paper/proc/show_info(mob/user)
	return info

// Coarse - Cramples the paper
// 1:1 - Returns random paper type
// Very Fine - Returns anomalous paper with various effects and blasts an EMP
/obj/item/paper/Conversion914(mode = MODE_ONE_TO_ONE, mob/living/user = usr)
	switch(mode)
		if(MODE_COARSE)
			if(icon_state == "scrap")
				return
			info = stars(info, 85)
			icon_state = "scrap"
			return src
		if(MODE_ONE_TO_ONE)
			return pick(typesof(/obj/item/paper))
		if(MODE_VERY_FINE)
			// You think you can just shove a shit-ton of paper in there? Fuck you, that's what you get
			if(locate(/obj/item/paper/self_writing) in get_turf(src))
				empulse(get_turf(src), 7, 14)
				if(istype(user))
					to_chat(user, SPAN_DANGER("You feel thousands of paper cuts appearing on your skin..."))
					for(var/i = 1 to 10)
						addtimer(CALLBACK(user, TYPE_PROC_REF(/mob/living, apply_damage), rand(3, 9), BRUTE, pick(BP_ALL_LIMBS), DAM_SHARP), i * (2 SECONDS))
						addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), get_turf(user), 'sounds/weapons/bladeslice.ogg', rand(25, 50), TRUE), i * (2 SECONDS))
				return null
			empulse(get_turf(src), rand(0, 2), rand(2, 7))
			return /obj/item/paper/self_writing
	return ..()

//For supply.
/obj/item/paper/manifest
	name = "supply manifest"
	var/is_copy = 1
/*
 * Premade paper
 */
/obj/item/paper/spacer
	language = LANGUAGE_ENGLISH

/obj/item/paper/Court
	name = "Judgement"
	info = "For crimes as specified, the offender is sentenced to:<BR>\n<BR>\n"

/obj/item/paper/crumpled
	name = "paper scrap"
	icon_state = "scrap"

/obj/item/paper/crumpled/on_update_icon()
	return

/obj/item/paper/crumpled/bloody
	icon_state = "scrap_bloodied"

/obj/item/paper/exodus_armory
	name = "armory inventory"
	info = "<center>\[logo]<BR><b><large>NSS Exodus</large></b><BR><i><date></i><BR><i>Armoury Inventory - Revision <field></i></center><hr><center>Armoury</center><list>\[*]<b>Deployable barriers</b>: 4\[*]<b>Biohazard suit(s)</b>: 1\[*]<b>Biohazard hood(s)</b>: 1\[*]<b>Face Mask(s)</b>: 1\[*]<b>Extended-capacity emergency oxygen tank(s)</b>: 1\[*]<b>Bomb suit(s)</b>: 1\[*]<b>Bomb hood(s)</b>: 1\[*]<b>Security officer's jumpsuit(s)</b>: 1\[*]<b>Brown shoes</b>: 1\[*]<b>Handcuff(s)</b>: 14\[*]<b>R.O.B.U.S.T. cartridges</b>: 7\[*]<b>Flash(s)</b>: 4\[*]<b>Can(s) of pepperspray</b>: 4\[*]<b>Gas mask(s)</b>: 6<field></list><hr><center>Secure Armoury</center><list>\[*]<b>LAEP90 Perun energy guns</b>: 4\[*]<b>Stun Revolver(s)</b>: 1\[*]<b>Electrolaser(s)</b>: 4\[*]<b>Stun baton(s)</b>: 4\[*]<b>Airlock Brace</b>: 3\[*]<b>Maintenance Jack</b>: 1\[*]<b>Stab Vest(s)</b>: 3\[*]<b>Riot helmet(s)</b>: 3\[*]<b>Riot shield(s)</b>: 3\[*]<b>Corporate security heavy armoured vest(s)</b>: 4\[*]<b>NanoTrasen helmet(s)</b>: 4\[*]<b>Portable flasher(s)</b>: 3\[*]<b>Tracking implant(s)</b>: 4\[*]<b>Chemical implant(s)</b>: 5\[*]<b>Implanter(s)</b>: 2\[*]<b>Implant pad(s)</b>: 2\[*]<b>Locator(s)</b>: 1<field></list><hr><center>Tactical Equipment</center><list>\[*]<b>Implanter</b>: 1\[*]<b>Death Alarm implant(s)</b>: 7\[*]<b>Security radio headset(s)</b>: 4\[*]<b>Ablative vest(s)</b>: 2\[*]<b>Ablative helmet(s)</b>: 2\[*]<b>Ballistic vest(s)</b>: 2\[*]<b>Ballistic helmet(s)</b>: 2\[*]<b>Tear Gas Grenade(s)</b>: 7\[*]<b>Flashbang(s)</b>: 7\[*]<b>Beanbag Shell(s)</b>: 7\[*]<b>Stun Shell(s)</b>: 7\[*]<b>Illumination Shell(s)</b>: 7\[*]<b>W-T Remmington 29x shotgun(s)</b>: 2\[*]<b>NT Mk60 EW Halicon ion rifle(s)</b>: 2\[*]<b>Hephaestus Industries G40E laser carbine(s)</b>: 4\[*]<b>Flare(s)</b>: 4<field></list><hr><b>Warden (print)</b>:<field><b>Signature</b>:<br>"

/obj/item/paper/exodus_cmo
	name = "outgoing CMO's notes"
	info = "<I><center>To the incoming CMO of Exodus:</I></center><BR><BR>I wish you and your crew well. Do take note:<BR><BR><BR>The Medical Emergency Red Phone system has proven itself well. Take care to keep the phones in their designated places as they have been optimised for broadcast. The two handheld green radios (I have left one in this office, and one near the Emergency Entrance) are free to be used. The system has proven effective at alerting Medbay of important details, especially during power outages.<BR><BR>I think I may have left the toilet cubicle doors shut. It might be a good idea to open them so the staff and patients know they are not engaged.<BR><BR>The new syringe gun has been stored in secondary storage. I tend to prefer it stored in my office, but 'guidelines' are 'guidelines'.<BR><BR>Also in secondary storage is the grenade equipment crate. I've just realised I've left it open - you may wish to shut it.<BR><BR>There were a few problems with their installation, but the Medbay Quarantine shutters should now be working again  - they lock down the Emergency and Main entrances to prevent travel in and out. Pray you shan't have to use them.<BR><BR>The new version of the Medical Diagnostics Manual arrived. I distributed them to the shelf in the staff break room, and one on the table in the corner of this room.<BR><BR>The exam/triage room has the walking canes in it. I'm not sure why we'd need them - but there you have it.<BR><BR>Emergency Cryo bags are beside the emergency entrance, along with a kit.<BR><BR>Spare paper cups for the reception are on the left side of the reception desk.<BR><BR>I've fed Runtime. She should be fine.<BR><BR><BR><center>That should be all. Good luck!</center>"

/obj/item/paper/exodus_bartender
	name = "shotgun permit"
	info = "This permit signifies that the Bartender is permitted to posess this firearm in the bar, and ONLY the bar. Failure to adhere to this permit will result in confiscation of the weapon and possibly arrest."

/obj/item/paper/exodus_holodeck
	name = "holodeck disclaimer"
	info = "Bruises sustained in the holodeck can be healed simply by sleeping."

/obj/item/paper/workvisa
	name = "Sol Work Visa"
	info = "<center><b><large>Work Visa of the Sol Central Government</large></b></center><br><center><img src = sollogo.png><br><br><i><small>Issued on behalf of the Secretary-General.</small></i></center><hr><BR>This paper hereby permits the carrier to travel unhindered through Sol territories, colonies, and space for the purpose of work and labor."
	desc = "A flimsy piece of laminated cardboard issued by the Sol Central Government."

/obj/item/paper/workvisa/New()
	..()
	icon_state = "workvisa" //Has to be here or it'll assume default paper sprites.

/obj/item/paper/travelvisa
	name = "Sol Travel Visa"
	info = "<center><b><large>Travel Visa of the Sol Central Government</large></b></center><br><center><img src = sollogo.png><br><br><i><small>Issued on behalf of the Secretary-General.</small></i></center><hr><BR>This paper hereby permits the carrier to travel unhindered through Sol territories, colonies, and space for the purpose of pleasure and recreation."
	desc = "A flimsy piece of laminated cardboard issued by the Sol Central Government."

/obj/item/paper/travelvisa/New()
	..()
	icon_state = "travelvisa"

/obj/item/paper/aromatherapy_disclaimer
	name = "aromatherapy disclaimer"
	info = "<I>The manufacturer and the retailer make no claims of the contained products' effacy.</I> <BR><BR><B>Use at your own risk.</B>"


#undef PAPER_CAMERA_DISTANCE
#undef PAPER_EYEBALL_DISTANCE

#undef PAPER_META
#undef PAPER_META_BAD
