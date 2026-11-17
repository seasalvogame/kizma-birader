class_name MatchDetailScreen
extends AppScreen
## One recorded online match: places, players and colours, date, duration,
## how it ended, and the verification data stored by the server.

var info := {}


func _title() -> String:
	return tr("DETAIL_TITLE")


func _build() -> void:
	info = params.get("match", {})
	var me := MatchRow.my_seat(info, Online.session.user_id)
	var rank := int(me.get("rank", 0))
	var head := UiKit.label(MatchRow.result_text(info, rank), "DisplayLabel", HORIZONTAL_ALIGNMENT_CENTER)
	head.add_theme_color_override("font_color", UiPalette.GOLD_300 if rank == 1 else UiPalette.ON_NIGHT)
	content.add_child(head)
	content.add_child(UiKit.label("%s · %s" % [tr("SETUP_TWO_PLAYERS") if int(info.get("players", 2)) == 2 else tr("SETUP_FOUR_PLAYERS"),
		MatchRow.when(String(info.get("ended_at", "")))], "DimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var places := card(tr("DETAIL_PLACES"))
	var players: Array = info.get("match_players", [])
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("rank", 9)) < int(b.get("rank", 9)))
	for p: Dictionary in players:
		var row := UiKit.hbox(UiTokens.S2)
		var place := UiKit.label("%d." % int(p.get("rank", 0)), "InkH2Label", HORIZONTAL_ALIGNMENT_CENTER)
		place.custom_minimum_size = Vector2(64, 0)
		if int(p.get("rank", 0)) == 1:
			place.add_theme_color_override("font_color", UiPalette.GOLD_700)
		row.add_child(place)
		var av := Avatar.new()
		av.custom_minimum_size = Vector2(80, 80)
		av.setup(MatchRow.player_name(p), String(p.get("color", "red")), bool(p.get("is_bot", false)))
		row.add_child(av)
		var n := UiKit.label(MatchRow.player_name(p), "InkH3Label")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(n)
		if String(p.get("user_id", "")) == Online.session.user_id:
			row.add_child(UiKit.chip(tr("ROLE_YOU"), UiPalette.MINT_500, UiPalette.INK_900))
		elif bool(p.get("left_match", false)):
			row.add_child(UiKit.label(tr("MATCH_STATUS_LEFT"), "InkDimLabel"))
		places.add_child(row)
	var facts := card(tr("DETAIL_INFO"))
	for pair: Array in [
			[tr("DETAIL_DURATION"), MatchRow.duration(info)],
			[tr("DETAIL_END"), tr("DETAIL_END_LEFT") if String(info.get("end_reason", "")) == "left" else tr("DETAIL_END_FINISHED")],
			[tr("DETAIL_MOVES"), str(int(info.get("action_count", 0)))],
			[tr("DETAIL_XP"), "+%d XP" % int(me.get("xp_gained", 0))],
			[tr("DETAIL_ID"), String(info.get("id", "")).substr(0, 8)],
			[tr("DETAIL_SERVER"), String(info.get("server_version", "")).substr(0, 8)]]:
		var r := UiKit.hbox(UiTokens.S2)
		var k := UiKit.label(pair[0], "InkDimLabel")
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(k)
		r.add_child(UiKit.label(pair[1], "InkBodyLabel"))
		facts.add_child(r)
	facts.add_child(wrapped(UiKit.label(tr("DETAIL_VERIFIED"), "InkDimLabel")))
