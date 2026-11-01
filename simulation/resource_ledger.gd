class_name ResourceLedger
extends RefCounted

# Measured supply intelligence. Every gain and loss is recorded from actual
# stockpile changes made by the simulation, never projected from design
# constants. Phases are attributed by before/after snapshots, so the sum of
# all recorded flows always equals the real change in stock. Survivor work
# adds finer per-activity detail with note(). The ledger is transient: it is
# not written to saves (schema stays v14) and restarts measuring after load.

const TRACKED := ["food","meals","water","medicine","materials","scrap","fuel","parts","battery"]
const BUCKET_HOURS := 1.0
const WINDOW_BUCKETS := 24
const MIN_REPORT_HOURS := 0.5
# Smaller residuals are floating-point noise from summing stockpile parts.
const EPSILON := 0.000000001

var _buckets: Array[Dictionary] = []
var _pending: Dictionary = {}
var _pending_total: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	_buckets = [_new_bucket()]
	_pending = _new_bucket()
	_pending_total = {}

static func _new_bucket() -> Dictionary:
	return {"hours": 0.0, "gain": {}, "loss": {}}

# Rolls the hourly window forward before this tick's flows are recorded.
func advance(sim_hours: float) -> void:
	if sim_hours <= 0.0:
		return
	if float(_buckets[_buckets.size()-1]["hours"]) >= BUCKET_HOURS:
		_buckets.append(_new_bucket())
		while _buckets.size() > WINDOW_BUCKETS:
			_buckets.pop_front()
	var current: Dictionary = _buckets[_buckets.size()-1]
	current["hours"] = float(current["hours"]) + sim_hours

# Detail for the phase currently being measured. Positive adds stock.
func note(resource: String, source: String, amount: float) -> void:
	if amount == 0.0 or resource not in TRACKED:
		return
	_add(_pending, resource, source, amount)
	_pending_total[resource] = float(_pending_total.get(resource, 0.0)) + amount

# Closes a phase: noted detail is kept and any unexplained remainder of the
# real stock change is attributed to the phase (or a per-resource override).
func record(source: String, before: Dictionary, after: Dictionary, overrides: Dictionary = {}) -> void:
	var bucket: Dictionary = _buckets[_buckets.size()-1]
	for resource in TRACKED:
		for side in ["gain", "loss"]:
			var flows: Dictionary = _pending[side]
			var detail: Dictionary = flows.get(resource, {})
			for key in detail.keys():
				_add(bucket, resource, str(key), float(detail[key]) * (1.0 if side == "gain" else -1.0))
		var delta := float(after.get(resource, 0.0)) - float(before.get(resource, 0.0))
		var residual := delta - float(_pending_total.get(resource, 0.0))
		if absf(residual) > EPSILON:
			_add(bucket, resource, str(overrides.get(resource, source)), residual)
	_pending = _new_bucket()
	_pending_total = {}

static func _add(bucket: Dictionary, resource: String, source: String, amount: float) -> void:
	if amount == 0.0:
		return
	var side := "gain" if amount > 0.0 else "loss"
	var flows: Dictionary = bucket[side]
	var by_source: Dictionary = flows.get(resource, {})
	by_source[source] = float(by_source.get(source, 0.0)) + absf(amount)
	flows[resource] = by_source

func measured_hours() -> float:
	var hours := 0.0
	for bucket in _buckets:
		hours += float(bucket["hours"])
	return hours

func _sum_side(resource: String, side: String) -> Dictionary:
	var totals := {}
	for bucket in _buckets:
		var flows: Dictionary = bucket[side]
		var by_source: Dictionary = flows.get(resource, {})
		for key in by_source.keys():
			totals[key] = float(totals.get(key, 0.0)) + float(by_source[key])
	return totals

# Signed sum of every recorded flow in the window for a resource.
func net_total(resource: String) -> float:
	var net := 0.0
	for amount in _sum_side(resource, "gain").values():
		net += float(amount)
	for amount in _sum_side(resource, "loss").values():
		net -= float(amount)
	return net

# Absolute amount (gain + loss) attributed to one source in the window.
func source_total(resource: String, source: String) -> float:
	return float(_sum_side(resource, "gain").get(source, 0.0)) + float(_sum_side(resource, "loss").get(source, 0.0))

static func _ranked(totals: Dictionary, per_day: float) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for key in totals.keys():
		var rate := float(totals[key]) * per_day
		if rate >= 0.01:
			ranked.append({"source": str(key), "per_day": rate})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["per_day"]) > float(b["per_day"]))
	return ranked

# Rates are per game day (24 game hours) over the measured window.
func report(resource: String, stock: float) -> Dictionary:
	var hours := measured_hours()
	var per_day := 24.0 / hours if hours > 0.0 else 0.0
	var gains := _sum_side(resource, "gain")
	var losses := _sum_side(resource, "loss")
	var produced := 0.0
	for amount in gains.values():
		produced += float(amount)
	var consumed := 0.0
	for amount in losses.values():
		consumed += float(amount)
	var net_per_day := (produced - consumed) * per_day
	var hours_to_empty := -1.0
	if hours >= MIN_REPORT_HOURS:
		if stock <= 0.0:
			hours_to_empty = 0.0
		elif net_per_day < -0.01:
			hours_to_empty = stock / (-net_per_day / 24.0)
	return {
		"resource": resource,
		"stock": stock,
		"hours": hours,
		"ready": hours >= MIN_REPORT_HOURS,
		"produced_per_day": produced * per_day,
		"consumed_per_day": consumed * per_day,
		"net_per_day": net_per_day,
		"hours_to_empty": hours_to_empty,
		"producers": _ranked(gains, per_day),
		"consumers": _ranked(losses, per_day)
	}
