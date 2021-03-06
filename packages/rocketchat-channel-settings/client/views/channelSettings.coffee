Template.channelSettings.helpers
	canEdit: ->
		return RocketChat.authz.hasAllPermission('edit-room', @rid)
	editing: (field) ->
		return Template.instance().editing.get() is field
	notDirect: ->
		return ChatRoom.findOne(@rid, { fields: { t: 1 }})?.t isnt 'd'
	roomType: ->
		return ChatRoom.findOne(@rid, { fields: { t: 1 }})?.t
	channelSettings: ->
		return RocketChat.ChannelSettings.getOptions()
	roomTypeDescription: ->
		roomType = ChatRoom.findOne(@rid, { fields: { t: 1 }})?.t
		if roomType is 'c'
			return t('Channel')
		else if roomType is 'p'
			return t('Private_Group')
	roomName: ->
		return ChatRoom.findOne(@rid, { fields: { name: 1 }})?.name
	roomTopic: ->
		return ChatRoom.findOne(@rid, { fields: { topic: 1 }})?.topic
	archivationState: ->
		return ChatRoom.findOne(@rid, { fields: { archived: 1 }})?.archived
	archivationStateDescription: ->
		archivationState = ChatRoom.findOne(@rid, { fields: { archived: 1 }})?.archived
		if archivationState is true
			return t('Room_archivation_state_true')
		else
			return t('Room_archivation_state_false')

Template.channelSettings.events
	'keydown input[type=text]': (e, t) ->
		if e.keyCode is 13
			e.preventDefault()
			t.saveSetting()

	'click [data-edit]': (e, t) ->
		e.preventDefault()
		t.editing.set($(e.currentTarget).data('edit'))
		setTimeout (-> t.$('input.editing').focus().select()), 100

	'click .cancel': (e, t) ->
		e.preventDefault()
		t.editing.set()

	'click .save': (e, t) ->
		e.preventDefault()
		t.saveSetting()

Template.channelSettings.onCreated ->
	@editing = new ReactiveVar

	@validateRoomType = =>
		type = @$('input[name=roomType]:checked').val()
		if type not in ['c', 'p']
			toastr.error t('Invalid_room_type', type)
		return true

	@validateRoomName = =>
		rid = Template.currentData()?.rid
		room = ChatRoom.findOne rid

		if not RocketChat.authz.hasAllPermission('edit-room', @rid) or room.t not in ['c', 'p']
			toastr.error t('Not_allowed')
			return false

		name = $('input[name=roomName]').val()
		if not /^[0-9a-z-_]+$/.test name
			toastr.error t('Invalid_room_name', name)
			return false

		return true

	@validateRoomTopic = =>
		return true

	@saveSetting = =>
		switch @editing.get()
			when 'roomName'
				if @validateRoomName()
					Meteor.call 'saveRoomSettings', @data?.rid, 'roomName', @$('input[name=roomName]').val(), (err, result) ->
						if err
							if err.error in [ 'duplicate-name', 'name-invalid' ]
								return toastr.error TAPi18n.__(err.reason, err.details.channelName)
							return toastr.error TAPi18n.__(err.reason)
						toastr.success TAPi18n.__ 'Room_name_changed_successfully'
			when 'roomTopic'
				if @validateRoomTopic()
					Meteor.call 'saveRoomSettings', @data?.rid, 'roomTopic', @$('input[name=roomTopic]').val(), (err, result) ->
						if err
							return toastr.error TAPi18n.__(err.reason)
						toastr.success TAPi18n.__ 'Room_topic_changed_successfully'
			when 'roomType'
				if @validateRoomType()
					Meteor.call 'saveRoomSettings', @data?.rid, 'roomType', @$('input[name=roomType]:checked').val(), (err, result) ->
						if err
							if err.error is 'invalid-room-type'
								return toastr.error TAPi18n.__(err.reason, err.details.roomType)
							return toastr.error TAPi18n.__(err.reason)
						toastr.success TAPi18n.__ 'Room_type_changed_successfully'
			when 'archivationState'
				if @$('input[name=archivationState]:checked').val() is 'true'
					if ChatRoom.findOne(@data.rid)?.archived isnt true
						Meteor.call 'archiveRoom', @data?.rid, (err, results) ->
							return toastr.error err.reason if err
							toastr.success TAPi18n.__ 'Room_archived'
				else
					if ChatRoom.findOne(@data.rid)?.archived is true
						Meteor.call 'unarchiveRoom', @data?.rid, (err, results) ->
							return toastr.error err.reason if err
							toastr.success TAPi18n.__ 'Room_unarchived'
		@editing.set()
