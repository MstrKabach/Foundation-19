var/list/tickets = list()
var/list/ticket_panels = list()

/datum/ticket
	var/datum/client_lite/owner
	var/list/assigned_admins = list()
	var/status = TICKET_OPEN
	var/list/msgs = list()
	var/datum/client_lite/closed_by
	var/id
	var/opened_time
	var/timeout = FALSE

/datum/ticket/New(datum/client_lite/owner)
	src.owner = owner
	tickets |= src
	id = tickets.len
	opened_time = world.time
	addtimer(CALLBACK(src, PROC_REF(timeoutcheck)), 5 MINUTES)

/datum/ticket/proc/timeoutcheck()
	if(status == TICKET_OPEN)
		timeout = TRUE
		close()

/datum/ticket/proc/close(datum/client_lite/closed_by)
	if(status == TICKET_CLOSED)
		return

	if(status == TICKET_ASSIGNED && !((closed_by.ckey in assigned_admin_ckeys()) || owner.ckey == closed_by.ckey) && alert(client_by_ckey(closed_by.ckey), "You are not assigned to this ticket. Are you sure you want to close it?",  "Close ticket?" , "Yes" , "No") != "Yes")
		return

	if(timeout == FALSE)
		var/client/real_client = client_by_ckey(closed_by.ckey)
		if(status == TICKET_ASSIGNED && (!real_client || !check_rights(R_ADMIN|R_MOD, FALSE, real_client))) // non-admins can only close a ticket if no admin has taken it
			return

	src.status = TICKET_CLOSED

	if(timeout == TRUE)
		to_chat(client_by_ckey(src.owner.ckey), SPAN_NOTICE("<b>Your ticket has timed out. Please adminhelp again if your issue is not resolved.</b>"))
	else
		src.closed_by = closed_by
		to_chat(client_by_ckey(src.owner.ckey), SPAN_NOTICE("<b>Your ticket has been closed by [closed_by.key].</b>"))
		message_staff(SPAN_NOTICE("<b>[src.owner.key_name(0)]</b>'s ticket has been closed by <b>[closed_by.key]</b>."))
		send2adminirc("[src.owner.key_name(0)]'s ticket has been closed by [closed_by.key].")

	update_ticket_panels()

	return 1

/datum/ticket/proc/take(datum/client_lite/assigned_admin)
	if(status == TICKET_CLOSED)
		return

	if(assigned_admin.ckey == owner.ckey)
		return

	if(status == TICKET_ASSIGNED && ((assigned_admin.ckey in assigned_admin_ckeys()) || alert(client_by_ckey(assigned_admin.ckey), "This ticket is already assigned. Do you want to add yourself to the ticket?",  "Join ticket?" , "Yes" , "No") != "Yes"))
		return

	assigned_admins |= assigned_admin
	src.status = TICKET_ASSIGNED

	message_staff(SPAN_NOTICE("<b>[assigned_admin.key]</b> has assigned themself to <b>[src.owner.key_name(0)]'s</b> ticket."))
	send2adminirc("[assigned_admin.key] has assigned themself to [src.owner.key_name(0)]'s ticket.")
	to_chat(client_by_ckey(src.owner.ckey), SPAN_NOTICE("<b>[assigned_admin.key] has added themself to your ticket and should respond shortly. Thanks for your patience!</b>"))

	update_ticket_panels()

	return 1

/datum/ticket/proc/assigned_admin_ckeys()
	. = list()

	for(var/datum/client_lite/assigned_admin in assigned_admins)
		. |= assigned_admin.ckey

/datum/ticket/proc/assigned_admin_keys()
	. = list()

	for(var/datum/client_lite/assigned_admin in assigned_admins)
		. |= assigned_admin.key

/proc/get_open_ticket_by_client(datum/client_lite/owner)
	for(var/datum/ticket/ticket in tickets)
		if(ticket.owner.ckey == owner.ckey && (ticket.status == TICKET_OPEN || ticket.status == TICKET_ASSIGNED))
			return ticket // there should only be one open ticket by a client at a time, so no need to keep looking

/datum/ticket/proc/is_active()
	if(status != TICKET_ASSIGNED)
		return 0

	for(var/datum/client_lite/admin in assigned_admins)
		var/client/admin_client = client_by_ckey(admin.ckey)
		if(admin_client && !admin_client.is_afk())
			return 1

	return 0

/datum/ticket_msg
	var/msg_from
	var/msg_to
	var/msg
	var/time_stamp

/datum/ticket_msg/New(msg_from, msg_to, msg)
	src.msg_from = msg_from
	src.msg_to = msg_to
	src.msg = msg
	src.time_stamp = time_stamp()

/datum/ticket_panel
	var/datum/ticket/open_ticket = null
	var/datum/browser/ticket_panel_window

/datum/ticket_panel/proc/get_dat()
	var/client/C = ticket_panel_window.user.client
	if(!C)
		return

	var/list/dat = list()

	var/list/ticket_dat = list()
	for(var/id = tickets.len, id >= 1, id--)
		var/datum/ticket/ticket = tickets[id]
		if(check_rights(R_ADMIN|R_MOD, FALSE, C) || ticket.owner.ckey == C.ckey)
			var/client/owner_client = client_by_ckey(ticket.owner.ckey)
			var/open = 0
			var/status = "Unknown status"
			var/color = "#6aa84f"
			switch(ticket.status)
				if(TICKET_OPEN)
					open = 1
					status = "Opened [round((world.time - ticket.opened_time) / (1 MINUTE))] minute\s ago, unassigned"
				if(TICKET_ASSIGNED)
					open = 2
					status = "Assigned to [english_list(ticket.assigned_admin_keys(), "no one")]"
					color = "#ffffff"
				if(TICKET_CLOSED)
					if(ticket.timeout == FALSE)
						status = "Closed by [ticket.closed_by.key]"
					else
						status = "Closed by timeout"
					color = "#cc2222"
			ticket_dat += "<li style='padding-bottom:10px;color:[color]'>"
			if(open_ticket && open_ticket == ticket)
				ticket_dat += "<i>"
			ticket_dat += "Ticket #[id] - [ticket.owner.key_name(0)] [owner_client ? "" : "(DC)"]<br />[status]<br /><a href='byond://?src=\ref[src];action=view;ticket=\ref[ticket]'>VIEW</a>"
			if(open)
				ticket_dat += " - <a href='byond://?src=\ref[src];action=pm;ticket=\ref[ticket]'>PM</a>"
				if(check_rights(R_ADMIN|R_MOD, FALSE, C))
					ticket_dat += " - <a href='byond://?src=\ref[src];action=take;ticket=\ref[ticket]'>[(open == 1) ? "TAKE" : "JOIN"]</a>"
				if(ticket.status != TICKET_CLOSED && (check_rights(R_ADMIN|R_MOD, FALSE, C) || ticket.status == TICKET_OPEN))
					ticket_dat += " - <a href='byond://?src=\ref[src];action=close;ticket=\ref[ticket]'>CLOSE</a>"
			if(check_rights(R_ADMIN|R_MOD, FALSE, C))
				if(owner_client && owner_client.mob)
					ticket_dat += " - [ADMIN_FULLMONTY_NONAME(owner_client.mob)]"
					if(ticket.status != TICKET_CLOSED)
						ticket_dat +=  " - <a href='?_src_=holder;autoresponse=[owner_client.mob]'>Autoresponse</a>"
			if(open_ticket && open_ticket == ticket)
				ticket_dat += "</i>"
			ticket_dat += "</li>"

	if(ticket_dat.len)
		dat += "<br /><div style='width:50%;float:left;'><p><b>Available tickets:</b></p><ul>[jointext(ticket_dat, null)]</ul></div>"

		if(open_ticket)
			dat += "<div style='width:50%;float:left;'><p><b>\[<a href='byond://?src=\ref[src];action=unview;'>X</a>\] Messages for ticket #[open_ticket.id]:</b></p>"

			var/list/msg_dat = list()
			for(var/datum/ticket_msg/msg in open_ticket.msgs)
				var/msg_to = msg.msg_to ? msg.msg_to : "Adminhelp"
				msg_dat += "<li>\[[msg.time_stamp]\] [msg.msg_from] -> [msg_to]: [C.holder ? generate_ahelp_key_words(C.mob, msg.msg) : msg.msg]</li>"

			if(msg_dat.len)
				dat += "<ul>[jointext(msg_dat, null)]</ul></div>"
			else
				dat += "<p>No messages to display.</p></div>"
	else
		dat += "<p>No tickets to display.</p>"
	dat += "</body></html>"

	return jointext(dat, null)

/datum/ticket_panel/Topic(href, href_list)
	if(usr && usr.client && usr != ticket_panel_window.user)
		if(href_list["close"]) // catch the case where a user switches mobs, then closes the window that was linked to the old mob
			ticket_panels -= usr.client
		else
			usr.client.view_tickets()
			var/datum/ticket_panel/new_panel = ticket_panels[usr.client]
			new_panel.open_ticket = open_ticket
			new_panel.Topic(href, href_list)
			return

	..()

	if(href_list["close"])
		ticket_panels -= usr.client

	switch(href_list["action"])
		if("unview")
			open_ticket = null
			ticket_panel_window.set_content(get_dat())
			ticket_panel_window.update()

	var/datum/ticket/ticket = locate(href_list["ticket"])
	if(!ticket)
		return

	switch(href_list["action"])
		if("view")
			open_ticket = ticket
			ticket_panel_window.set_content(get_dat())
			ticket_panel_window.update()
		if("take")
			ticket.take(client_repository.get_lite_client(usr.client))
		if("close")
			ticket.close(client_repository.get_lite_client(usr.client))
		if("pm")
			ticket.take(client_repository.get_lite_client(usr.client))
			if(check_rights(R_ADMIN|R_MOD, FALSE, usr) && ticket.owner.ckey != usr.ckey)
				usr.client.cmd_admin_pm(client_by_ckey(ticket.owner.ckey), ticket = ticket)
			else if(ticket.status == TICKET_ASSIGNED)
				// manually check that the target client exists here as to not spam the usr for each logged out admin on the ticket
				var/admin_found = 0
				for(var/datum/client_lite/admin in ticket.assigned_admins)
					var/client/admin_client = client_by_ckey(admin.ckey)
					if(admin_client)
						admin_found = 1
						usr.client.cmd_admin_pm(admin_client, ticket = ticket)
						break
				if(!admin_found)
					to_chat(usr, SPAN_WARNING("Error: Private-Message: Client not found. They may have lost connection, so please be patient!"))
			else
				usr.client.adminhelp(input(usr,"", "adminhelp \"text\"") as text)

/client/verb/view_tickets()
	set name = "View Tickets"
	set category = "Staff Help"

	var/datum/ticket_panel/ticket_panel = new()
	ticket_panels[src] = ticket_panel
	ticket_panel.ticket_panel_window = new(src.mob, "ticketpanel", "Ticket Manager", 1024, 768, ticket_panel)

	ticket_panel.ticket_panel_window.set_content(ticket_panel.get_dat())
	ticket_panel.ticket_panel_window.open()

/proc/update_ticket_panels()
	for(var/client/C in ticket_panels)
		var/datum/ticket_panel/ticket_panel = ticket_panels[C]
		if(C.mob != ticket_panel.ticket_panel_window.user)
			C.view_tickets()
		else
			ticket_panel.ticket_panel_window.set_content(ticket_panel.get_dat())
			ticket_panel.ticket_panel_window.update()
