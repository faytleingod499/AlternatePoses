extends Node

# Alternate Poses: an addon for Hugs and More (needs Hugs and More 1.3.1 or newer).
#
# It adds more two-player emotes to the F menu of Hugs and More: a side hug, holding hands,
# a twirl and a bow. They work exactly like the hug, high five and kiss: press F near a player, pick one,
# they say yes, and both of you play it. Both players need Alternate Poses (the menu only offers these to
# players who have it). Nothing here sends anything by itself: the invitation and the sync go through Hugs
# and More; this mod only announces that it is installed ("alternateposes_v") and draws the poses.

const VERSION = "1.3.0"
const NEEDS_API = 2          # Hugs and More 1.3.1 or newer
const API_META = "hugsandmore_api"
const ANNOUNCE_KEY = "alternateposes_v"
const SKELETON_PATH = "body/player_body/Armature/Skeleton"
const FINGER = 0.08          # the same fingertip allowance Hugs and More uses (skeleton units)

var steam = null
var hugs = null              # the Hugs and More node
var clock = 0.0
var next_announce = 0.0
var announced_lobby = 0
var reported_missing = false

# the emotes: id -> what Hugs and More needs to know, and the method that draws it
const EMOTES = {
	"sidehug": {"label": "Side hug", "ask": "wants a side hug!", "answer": "Hug", "time": 4.0, "method": "pose_sidehug"},
	"holdhands": {"label": "Hold hands", "ask": "wants to hold hands!", "answer": "Hold hands", "time": 0.0, "move_limit": 0.4, "method": "pose_holdhands"},
	"twirl": {"label": "Twirl", "ask": "wants to twirl with you!", "answer": "Twirl", "time": 0.0, "move_limit": 0.4, "method": "pose_twirl"},
	"bow": {"label": "Bow", "ask": "bows to you!", "answer": "Bow back", "time": 2.4, "method": "pose_bow"},
}
const ORDER = ["sidehug", "holdhands", "twirl", "bow"]


func _ready():
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")


func _exit_tree():
	_unregister()
	_announce("")


func _process(delta):
	clock += delta
	var root = get_tree().root
	var found = root.get_meta("hugsandmore_api") if root.has_meta(API_META) else null
	if found != hugs:
		_unregister()
		hugs = null
		if found != null and is_instance_valid(found) and found.has_method("register_emote") \
				and found.has_method("api_version") and found.api_version() >= NEEDS_API:
			hugs = found
			_register()
	if hugs == null and not reported_missing and clock > 20.0:
		reported_missing = true
		print("[AlternatePoses] Hugs and More 1.3.1 or newer was not found: the extra poses are not available")
	if clock >= next_announce:
		next_announce = clock + 3.0
		_announce(VERSION if hugs != null else "")


func _register():
	for id in ORDER:
		var e = EMOTES[id]
		hugs.register_emote(id, {"label": e["label"], "ask": e["ask"], "answer": e["answer"], "time": e["time"],
			"node": self, "method": e["method"], "needs": ANNOUNCE_KEY, "move_limit": e.get("move_limit", 0.6)})
	print("[AlternatePoses] ", VERSION, " added ", ORDER.size(), " emotes to Hugs and More")


func _unregister():
	if hugs != null and is_instance_valid(hugs) and hugs.has_method("unregister_emote"):
		for id in ORDER:
			hugs.unregister_emote(id)


# tells the lobby that I have this addon, so the others only offer these emotes to me. It is checked again
# every few seconds, as a write made while still joining the lobby is lost.
func _announce(text):
	var net = get_node_or_null("/root/Network")
	if steam == null or net == null or net.PLAYING_OFFLINE or net.STEAM_LOBBY_ID <= 0:
		return
	if not steam.has_method("setLobbyMemberData") or not steam.has_method("getLobbyMemberData"):
		return
	var lobby = net.STEAM_LOBBY_ID
	var me = int(net.STEAM_ID)
	if str(steam.getLobbyMemberData(lobby, me, ANNOUNCE_KEY)) != text:
		steam.setLobbyMemberData(lobby, ANNOUNCE_KEY, text)
		if text != "" and lobby != announced_lobby:
			print("[AlternatePoses] ", VERSION, " announced in lobby ", lobby)
		announced_lobby = lobby


# --- helpers ---

# Both stand side by side facing the same way, each on the side they were already on. Worked out once
# when the emote starts: p["front"] is the way they face, p["side_a"] / p["side_b"] which side (+1 = my left)
# each one is on.
func _side_frame(p, h):
	var frame = h._pair_frame(p)
	var mid = frame[1]
	if not p.has("front"):
		var left0 = Vector3.UP.cross(frame[0]).normalized()
		var facing = h._facing(p["pa"]) + h._facing(p["pb"])
		p["front"] = left0 if facing.dot(left0) >= 0.0 else -left0
		var left = Vector3.UP.cross(p["front"]).normalized()
		var a = h._flat(p["pa"].global_transform.origin) - mid
		p["side_a"] = 1.0 if a.dot(left) >= 0.0 else -1.0
	var front = p["front"]
	return {"mid": mid, "front": front, "left": Vector3.UP.cross(front).normalized(), "side_a": p["side_a"], "side_b": -p["side_a"]}


# [length of an arm from shoulder to fingertips, half the width between the shoulders], in the world
func _arm_size(h, node):
	var size = h._player_size(node)
	var sk = node.get_node_or_null(SKELETON_PATH)
	if sk != null:
		var arm = sk.find_bone("arm.l")
		var elbow = sk.find_bone("elbow.l")
		var hand = sk.find_bone("hand.l")
		var arm_r = sk.find_bone("arm.r")
		if arm >= 0 and elbow >= 0 and hand >= 0 and arm_r >= 0:
			var pa = sk.get_bone_global_pose_no_override(arm).origin
			var pe = sk.get_bone_global_pose_no_override(elbow).origin
			var ph = sk.get_bone_global_pose_no_override(hand).origin
			var pr = sk.get_bone_global_pose_no_override(arm_r).origin
			var scale = sk.global_transform.basis.get_scale().y
			return [((pe - pa).length() + (ph - pe).length() + FINGER) * scale, (pa - pr).length() / 2.0 * scale]
	return [0.75 * size, 0.2 * size]


func _hearts_now_and_then(p, h, at, every):
	if not p["ending"] and p["t"] >= p["next_hearts"]:
		p["next_hearts"] = p["t"] + every
		h._hearts(p["pa"], at)


# --- side hug ---
# Side by side, facing the same way, each puts the arm nearest the other round the other's back and they
# lean their heads together and sway a little.

const SIDEHUG_DIST = 0.40    # how far from the middle each one stands (times their size): close, the arms are short
const SIDEHUG_HEAD_TIP = 8.0 # degrees: the heads are big, so they tip away from each other

func pose_sidehug(p, h):
	var fr = _side_frame(p, h)
	var sa = h._player_size(p["pa"])
	var sb = h._player_size(p["pb"])
	var sway = deg2rad(3.0) * sin(p["t"] * 2.0) * p["w"]
	var spot_a = fr["mid"] + fr["left"] * fr["side_a"] * SIDEHUG_DIST * sa
	var spot_b = fr["mid"] + fr["left"] * fr["side_b"] * SIDEHUG_DIST * sb
	_sidehug_one(p, h, p["pa"], fr, fr["side_a"], spot_a, spot_b, sb, sway)
	_sidehug_one(p, h, p["pb"], fr, fr["side_b"], spot_b, spot_a, sa, sway)
	_hearts_now_and_then(p, h, Vector3(fr["mid"].x, max(h._head_y(p["pa"]), h._head_y(p["pb"])) + 0.8 * max(sa, sb), fr["mid"].z), 1.8)


func _sidehug_one(p, h, node, fr, side, spot, their_spot, their_size, sway):
	var body = h._place_body(node, fr["front"], spot, 0.0, sway, p["w"], fr["mid"])
	if body == null:
		return
	var toward = -fr["left"] * side           # the way my partner is
	var other = p["pb"] if node == p["pa"] else p["pa"]
	# the hand rests on my partner's waist on the side next to me, a little behind
	var y = h._shoulder_y(other) - 0.30 * their_size
	var target = Vector3(their_spot.x, y, their_spot.z) - toward * 0.15 * their_size - fr["front"] * 0.06 * their_size
	h._reach(body, -side, target, Vector3.DOWN * 0.7 - fr["front"] * 0.5, fr["left"], p["w"])
	h._tilt_head_toward(body, fr["front"], -toward, SIDEHUG_HEAD_TIP, p["w"])


# --- hold hands ---
# Side by side, the two hands that are next to each other join between them and swing a little.

const HOLD_ANGLE = 10.0      # degrees the straight arms swing inward from hanging straight down: this sets how close they stand
const HOLD_HEAD_TIP = 20.0   # the heads are big, so at this distance they tip away from each other
const HOLD_SWING = 0.10      # how far the hands swing forward and back (times their average size)

func pose_holdhands(p, h):
	_hold(p, h, 0.0, 1.0, true)


# turn is how far the pair has turned about the middle, swing how much the hands swing, calm whether it is the
# quiet kind (with hearts) rather than the twirl
func _hold(p, h, turn, swing, calm):
	var fr = _side_frame(p, h)
	var sa = h._player_size(p["pa"])
	var sb = h._player_size(p["pb"])
	var aa = _arm_size(h, p["pa"])
	var ab = _arm_size(h, p["pb"])
	# arms straight and pointing (almost) down: the near hands only have to swing sideways to meet, so each stands
	# about a shoulder's width plus that swing from the middle
	var da = aa[1] + aa[0] * sin(deg2rad(HOLD_ANGLE))
	var db = ab[1] + ab[0] * sin(deg2rad(HOLD_ANGLE))
	var rot = Basis(Vector3.UP, turn)
	var swing_at = fr["front"] * HOLD_SWING * (sa + sb) / 2.0 * sin(p["t"] * 2.6) * swing * p["w"]
	var low_a = h._shoulder_y(p["pa"]) - aa[0] * cos(deg2rad(HOLD_ANGLE))
	var low_b = h._shoulder_y(p["pb"]) - ab[0] * cos(deg2rad(HOLD_ANGLE))
	var contact = Vector3(fr["mid"].x, (low_a + low_b) / 2.0, fr["mid"].z) + swing_at
	_hold_one(p, h, p["pa"], fr, fr["side_a"], da, turn, rot, contact, calm)
	_hold_one(p, h, p["pb"], fr, fr["side_b"], db, turn, rot, contact, calm)
	if calm:
		_hearts_now_and_then(p, h, Vector3(fr["mid"].x, max(h._head_y(p["pa"]), h._head_y(p["pb"])) + 0.8 * max(sa, sb), fr["mid"].z), 2.2)


func _hold_one(p, h, node, fr, side, dist, turn, rot, contact, calm):
	var spot = fr["mid"] + fr["left"] * side * dist
	var body = h._place_body(node, fr["front"], spot, 0.0, turn, p["w"], fr["mid"])
	if body == null:
		return
	# the place it ended up at, once the pair has turned
	body["spot"] = fr["mid"] + rot.xform(spot - fr["mid"])
	var left = rot.xform(fr["left"])
	var front = rot.xform(fr["front"])
	var away = left * side
	h._reach(body, -side, contact, Vector3.DOWN, left, p["w"])
	# the heads are big, so they tip away from each other
	h._tilt_head_toward(body, front, away, HOLD_HEAD_TIP, p["w"])


# --- twirl ---
# Holding hands, they keep turning around each other until one of them walks away.

const TWIRL_SPEED = 2.0      # radians a second: a turn in about three seconds
const TWIRL_EASE = 1.0       # seconds it takes to get up to speed

func pose_twirl(p, h):
	var t = p["t"]
	var turn = TWIRL_SPEED * (t * t / (2.0 * TWIRL_EASE) if t < TWIRL_EASE else t - TWIRL_EASE / 2.0)
	_hold(p, h, fmod(turn, TAU), 0.0, false)


# --- bow ---
# They stand a little way apart, face to face, and both bow.

const BOW_DEGREES = 30.0
const BOW_DISTANCE = 1.0     # how far each stands from the middle (times their size)

func pose_bow(p, h):
	var frame = h._pair_frame(p)
	var dir = frame[0]
	var mid = frame[1]
	var bend = smoothstep(0.0, 0.6, p["t"]) - smoothstep(1.4, 2.0, p["t"])
	_bow_one(p, h, p["pa"], dir, mid, bend)
	_bow_one(p, h, p["pb"], -dir, mid, bend)


func _bow_one(p, h, node, dir, mid, bend):
	var size = h._player_size(node)
	var body = h._place_body(node, dir, mid, 2.0 * BOW_DISTANCE * size, 0.0, p["w"])
	if body == null:
		return
	var sk = body["sk"]
	var torso = sk.find_bone("torso")
	var head = sk.find_bone("head")
	if torso < 0 or head < 0:
		return
	var g_torso = body["rebase"] * sk.get_bone_global_pose_no_override(torso)
	var g_head = body["rebase"] * sk.get_bone_global_pose_no_override(head)
	var axis = body["Winv"].basis.xform(Vector3.UP.cross(dir)).normalized()
	var toward = body["Winv"].basis.xform(dir).normalized()
	# whichever way round the axis is, tip towards the other one (the head moves that way)
	var deg = BOW_DEGREES
	var offset = g_head.origin - g_torso.origin
	if (offset.rotated(axis, deg2rad(deg)) - offset).dot(toward) < 0:
		deg = -deg
	sk.set_bone_global_pose_override(torso, Transform(Basis(axis, deg2rad(deg * bend)) * g_torso.basis, g_torso.origin), p["w"], true)
