/*	Photography!
 *	Contains:
 *		Camera
 *		Camera Film
 *		Photos
 *		Photo Albums
 */

/*******
* film *
*******/
/obj/item/device/camera_film
	name = "film cartridge"
	icon = 'icons/obj/photography.dmi'
	desc = "A camera film cartridge. Insert it into a camera to reload it."
	icon_state = "film"
	item_state = "electropack"
	w_class = ITEM_SIZE_TINY


/********
* photo *
********/
var/global/photo_count = 0

/obj/item/photo
	name = "photo"
	icon = 'icons/obj/photography.dmi'
	icon_state = "photo"
	item_state = "paper"
	randpixel = 10
	w_class = ITEM_SIZE_TINY
	var/id
	///Big photo image
	var/icon/img
	///Scribble on the back.
	var/scribble
	var/image/tiny
	var/photo_size = 3
	///Photo data containing weakrefs to mobs and objects within the photo.
	var/list/weakref/meta_data

/obj/item/photo/New()
	id = photo_count++
	LAZYINITLIST(meta_data)

/obj/item/photo/Destroy()
	. = ..()
	LAZYCLEARLIST(meta_data)

/obj/item/photo/attack_self(mob/user as mob)
	user.examinate(src)

/obj/item/photo/on_update_icon()
	cut_overlays()
	var/scale = 8/(photo_size*32)
	var/image/small_img = image(img)
	small_img.transform *= scale
	small_img.pixel_x = -32*(photo_size-1)/2 - 3
	small_img.pixel_y = -32*(photo_size-1)/2
	add_overlay(small_img)

	tiny = image(img)
	tiny.transform *= 0.5*scale
	tiny.underlays += image('icons/obj/bureaucracy.dmi',"photo")
	tiny.pixel_x = -32*(photo_size-1)/2 - 3
	tiny.pixel_y = -32*(photo_size-1)/2 + 3

/obj/item/photo/attackby(obj/item/P as obj, mob/user as mob)
	if(istype(P, /obj/item/pen))
		var/txt = sanitize(input(user, "What would you like to write on the back?", "Photo Writing", null)  as text, 128)
		if(loc == user && user.stat == 0)
			scribble = txt
	..()

/obj/item/photo/examine(mob/user, distance)
	. = TRUE
	if(!img)
		return
	if(distance <= 1)
		show(user)
		to_chat(user, desc)
	else
		to_chat(user, SPAN_NOTICE("It is too far away."))

/obj/item/photo/proc/show(mob/user as mob)
	send_rsc(user, img, "tmp_photo_[id].png")
	var/output = "<html><head><title>[name]</title></head>"
	output += "<body style='overflow:hidden;margin:0;text-align:center'>"
	output += "<img src='tmp_photo_[id].png' width='[64*photo_size]' style='-ms-interpolation-mode:nearest-neighbor' />"
	output += "[scribble ? "<br>Written on the back:<br><i>[scribble]</i>" : ""]"
	output += "</body></html>"
	show_browser(user, output, "window=book;size=[64*photo_size]x[scribble ? 400 : 64*photo_size]")
	for(var/atom/pAtom in resolveWeakrefList(meta_data))
		SEND_SIGNAL(pAtom, COMSIG_PHOTO_SHOWN_OF, src, user)
	onclose(user, "[name]")
	return

/obj/item/photo/verb/rename()
	set name = "Rename photo"
	set category = "Object"
	set src in usr

	var/n_name = sanitizeSafe(input(usr, "What would you like to label the photo?", "Photo Labelling", null)  as text, MAX_NAME_LEN)
	//loc.loc check is for making possible renaming photos in clipboards
	if(!n_name || !CanInteract(usr, GLOB.deep_inventory_state))
		return
	SetName("[(n_name ? text("[n_name]") : "photo")]")
	add_fingerprint(usr)
	return


/**************
* photo album *
**************/
/obj/item/storage/photo_album
	name = "Photo album"
	icon = 'icons/obj/photography.dmi'
	icon_state = "album"
	item_state = "briefcase"
	w_class = ITEM_SIZE_NORMAL //same as book
	storage_slots = DEFAULT_BOX_STORAGE //yes, that's storage_slots. Photos are w_class 1 so this has as many slots equal to the number of photos you could put in a box
	can_hold = list(/obj/item/photo)

/obj/item/storage/photo_album/MouseDrop(obj/over_object as obj)

	if((istype(usr, /mob/living/carbon/human)))
		var/mob/M = usr
		if(!( istype(over_object, /obj/screen) ))
			return ..()
		playsound(loc, SFX_RUSTLE, 50, 1, -5)
		if((!( M.restrained() ) && !( M.stat ) && M.back == src))
			switch(over_object.name)
				if("r_hand")
					if(M.unEquip(src))
						M.put_in_r_hand(src)
				if("l_hand")
					if(M.unEquip(src))
						M.put_in_l_hand(src)
			add_fingerprint(usr)
			return
		if(over_object == usr && in_range(src, usr) || list_find(usr.contents, src))
			if(usr.s_active)
				usr.s_active.close(usr)
			show_to(usr)
			return
	return

/*********
* camera *
*********/
/obj/item/device/camera
	name = "camera"
	icon = 'icons/obj/photography.dmi'
	desc = "A polaroid camera."
	icon_state = "camera"
	item_state = "electropack"
	w_class = ITEM_SIZE_SMALL
	obj_flags = OBJ_FLAG_CONDUCTIBLE
	slot_flags = SLOT_BELT
	matter = list(MATERIAL_ALUMINIUM = 1000, MATERIAL_PLASTIC = 750)
	var/pictures_max = 10
	var/pictures_left = 10
	var/on = 1
	var/icon_on = "camera"
	var/icon_off = "camera_off"
	var/size = 3

/obj/item/device/camera/on_update_icon()
	var/datum/extension/base_icon_state/bis = get_extension(src, /datum/extension/base_icon_state)
	if(on)
		icon_state = "[bis.base_icon_state]"
	else
		icon_state = "[bis.base_icon_state]_off"
/obj/item/device/camera/Initialize()
	set_extension(src, /datum/extension/base_icon_state, icon_state)
	update_icon()
	. = ..()

/obj/item/device/camera/verb/change_size()
	set name = "Set Photo Focus"
	set category = "Object"
	var/nsize = input("Photo Size","Pick a size of resulting photo.") as null|anything in list(1,3,5,7)
	if(nsize)
		size = nsize
		to_chat(usr, SPAN_NOTICE("Camera will now take [size]x[size] photos."))

/obj/item/device/camera/attack(mob/living/carbon/human/M as mob, mob/user as mob)
	return

/obj/item/device/camera/attack_self(mob/user as mob)
	on = !on
	update_icon()
	to_chat(user, "You switch the camera [on ? "on" : "off"].")
	return

/obj/item/device/camera/attackby(obj/item/I as obj, mob/user as mob)
	if(istype(I, /obj/item/device/camera_film))
		if(pictures_left)
			to_chat(user, SPAN_NOTICE("[src] still has some film in it!"))
			return
		to_chat(user, SPAN_NOTICE("You insert [I] into [src]."))
		qdel(I)
		pictures_left = pictures_max
		return
	..()


/obj/item/device/camera/proc/get_mobs(turf/the_turf as turf)
	var/mob_detail
	for(var/atom/our_atom in the_turf)
		if(our_atom.invisibility) continue
		if(iscarbon(our_atom))
			var/mob/living/carbon/A = our_atom
			var/holding = null
			if(A.l_hand || A.r_hand)
				if(A.l_hand) holding = "They are holding \a [A.l_hand]"
				if(A.r_hand)
					if(holding)
						holding += " and \a [A.r_hand]"
					else
						holding = "They are holding \a [A.r_hand]"

			if(!mob_detail)
				mob_detail = "You can see [A] on the photo[(A.health / A.maxHealth) < 0.75 ? " - [A] looks hurt":""].[holding ? " [holding]":"."]. "
			else
				mob_detail += "You can also see [A] on the photo[(A.health / A.maxHealth)< 0.75 ? " - [A] looks hurt":""].[holding ? " [holding]":"."]."

		else if(our_atom.SCP)
			if (!mob_detail)
				mob_detail = "You can see [our_atom.SCP] on the photo. "
			else
				mob_detail += "You can also see [our_atom.SCP] on the photo. "
	return mob_detail

/obj/item/device/camera/afterattack(atom/target as mob|obj|turf|area, mob/user as mob, flag)
	if(!on || !pictures_left || ismob(target.loc)) return
	captureimage(target, user, flag)

	playsound(loc, pick('sounds/items/polaroid1.ogg', 'sounds/items/polaroid2.ogg'), 75, 1, -3)

	pictures_left--
	to_chat(user, SPAN_NOTICE("[pictures_left] photos left."))

	on = 0
	update_icon()

/obj/item/device/camera/examine(mob/user)
	. = ..()
	to_chat(user, "It has [pictures_left] photo\s left.")

//Proc for capturing check
/mob/living/proc/can_capture_turf(turf/T)
	var/viewer = src
	if(src.client)		//To make shooting through security cameras possible
		viewer = src.client.eye
	var/can_see = (T in view(viewer))
	return can_see

/obj/item/device/camera/proc/captureimage(atom/target, mob/living/user, flag)
	var/x_c = target.x - (size-1)/2
	var/y_c = target.y + (size-1)/2
	var/z_c	= target.z
	var/mobs = ""
	var/list/weakref/new_meta_data = list()
	for(var/i = 1 to size)
		for(var/j = 1 to size)
			var/turf/T = locate(x_c, y_c, z_c)
			if(user.can_capture_turf(T))
				mobs += get_mobs(T)
				for(var/atom/movable/mAtom as obj|mob in T)
					new_meta_data += weakref(mAtom)
					SEND_SIGNAL(mAtom, COMSIG_PHOTO_TAKEN_OF, src, user)
			x_c++
		y_c--
		x_c = x_c - size

	var/obj/item/photo/p = createpicture(target, user, mobs, flag, new_meta_data)
	printpicture(user, p)

/obj/item/device/camera/proc/createpicture(atom/target, mob/user, mobs, flag, metadata)
	var/x_c = target.x - (size-1)/2
	var/y_c = target.y - (size-1)/2
	var/z_c	= target.z
	var/icon/photoimage = generate_image(x_c, y_c, z_c, size, CAPTURE_MODE_REGULAR, user, 0)

	var/obj/item/photo/p = new()
	p.img = photoimage
	p.desc = mobs
	p.photo_size = size
	p.update_icon()
	p.meta_data = metadata

	return p

/obj/item/device/camera/proc/printpicture(mob/user, obj/item/photo/p)
	if(!user.put_in_inactive_hand(p))
		p.dropInto(loc)

/obj/item/photo/proc/copy(copy_id = 0)
	var/obj/item/photo/p = new/obj/item/photo()

	p.SetName(name) // Do this first, manually, to make sure listeners are alerted properly.
	p.appearance = appearance

	p.tiny = new
	p.tiny.appearance = tiny.appearance
	p.img = icon(img)

	p.photo_size = photo_size
	p.scribble = scribble

	if(copy_id)
		p.id = id

	return p

/obj/item/photo/scp096/scp096_photo
	name =  "???? photo"

/obj/item/photo/scp096/scp096_photo/examine(mob/user, distance)
	. = ..()
	var/mob/living/scp096/scp_to_trigger = locate(/mob/living/scp096) in GLOB.SCP_list
	if(distance <= 1)
		scp_to_trigger.trigger(user)
		to_chat(user, SPAN_DANGER("You catch [scp_to_trigger]"))
	else
		to_chat(user, SPAN_NOTICE("It is too far away."))
