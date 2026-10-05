class_name EconomySimulation
extends RefCounted

var credits := 120.0
var market_index := {
	"food": 1.0,
	"water": 1.0,
	"medicine": 1.8,
	"materials": 1.25,
	"scrap": 0.75,
	"fuel": 1.6,
	"parts": 2.2
}
var trade_pressure := {
	"food": 0.0,
	"water": 0.0,
	"medicine": 0.0,
	"materials": 0.0,
	"scrap": 0.0,
	"fuel": 0.0,
	"parts": 0.0
}
var industry_stock := {
	"fuel": 30.0,
	"parts": 8.0,
	"tools": 4.0,
	"components": 0.0
}
var recipes := {
	"Machine Parts":{"input":{"scrap":4.0,"materials":2.0},"output":{"parts":1.0},"work":24.0},
	"Components":{"input":{"parts":1.0,"materials":1.0},"output":{"components":2.0},"work":20.0},
	"Tool Kit":{"input":{"parts":2.0,"materials":2.0},"output":{"tools":1.0},"work":32.0},
	"Fuel Blend":{"input":{"scrap":1.0,"materials":1.0},"output":{"fuel":3.0},"work":18.0},
	"Vehicle Repair Kit":{"input":{"parts":2.0,"tools":1.0,"components":2.0},"output":{"repair_kits":1.0},"work":38.0}
}
var production_queue: Array[Dictionary] = []
var next_batch_id := 1
var price_update_hour := 24.0
var trade_log: Array[Dictionary] = []
var vehicles := [
	{"name":"Utility Truck 01","type":"truck","condition":68.0,"fuel":16.0,"capacity":30.0,"operational":true}
]
var warehouse_capacity := 100.0
var warehouse_used := 0.0
var warehouse_pressure := 0.0
var production_efficiency := 1.0
var bottleneck_reason := ""
var fuel_consumed_today := 0.0
var next_warehouse_check_hour := 24.0
var repair_kits := 0.0
var regional_markets := {
	"9":{
		"location_id":9,
		"faction":"Cedar Union",
		"reputation":18.0,
		"price_modifiers":{"food":0.92,"water":1.08,"medicine":1.16,"materials":0.88,"scrap":0.82,"fuel":0.94,"parts":1.12},
		"stock":{"food":30.0,"water":24.0,"medicine":8.0,"materials":34.0,"scrap":40.0,"fuel":22.0,"parts":10.0},
		"next_caravan_hour":72.0
	},
	"10":{
		"location_id":10,
		"faction":"Riverbend Collective",
		"reputation":12.0,
		"price_modifiers":{"food":0.84,"water":0.90,"medicine":1.05,"materials":1.12,"scrap":0.94,"fuel":1.18,"parts":0.98},
		"stock":{"food":48.0,"water":42.0,"medicine":10.0,"materials":18.0,"scrap":26.0,"fuel":12.0,"parts":16.0},
		"next_caravan_hour":96.0
	}
}
var trade_caravans: Array[Dictionary] = []
var next_caravan_id := 1

func initialize(sim: SettlementSimulation) -> void:
	if production_queue.is_empty():
		queue_recipe(sim,"Machine Parts",2)
		queue_recipe(sim,"Components",2)

func update(sim: SettlementSimulation, sim_hours: float) -> void:
	_update_market(sim)
	_update_warehouse(sim)
	_update_production(sim,sim_hours)
	_update_vehicle_state(sim,sim_hours)
	_update_regional_trade(sim,sim_hours)

func queue_recipe(sim: SettlementSimulation, recipe_name:String, quantity:int=1) -> bool:
	if not recipes.has(recipe_name) or quantity <= 0:
		return false
	for i in range(quantity):
		production_queue.append({
			"id":next_batch_id,
			"recipe":recipe_name,
			"progress":0.0,
			"status":"queued"
		})
		next_batch_id += 1
	sim.add_event("PRODUCTION QUEUED","%d x %s added to workshop queue." % [quantity,recipe_name],"intel")
	return true

func _update_production(sim:SettlementSimulation, sim_hours:float) -> void:
	var workers:Array[Dictionary] = []
	for c in sim.get_settlement_citizens():
		if c["job"] in ["Engineer","Builder"] and not c.get("incarcerated",false):
			workers.append(c)
	if workers.is_empty():
		bottleneck_reason = "NO INDUSTRIAL LABOR"
		production_efficiency = 0.0
		return

	var workshop_count := 0
	for building in sim.buildings:
		if building["type"] == "industry":
			workshop_count += 1
	var active_lines := maxi(1, workshop_count)
	var completed_lines := 0
	bottleneck_reason = ""

	for batch in production_queue:
		if batch["status"] == "complete":
			continue
		if completed_lines >= active_lines:
			break
		var recipe:Dictionary = recipes[batch["recipe"]]
		if batch["status"] == "queued":
			if not _consume_inputs(sim,recipe["input"]):
				bottleneck_reason = "MISSING INPUTS // %s" % batch["recipe"]
				production_efficiency = 0.25
				continue
			batch["status"] = "working"

		var worker := workers[completed_lines % workers.size()]
		var skill := maxf(float(worker["skills"].get("engineering",20)),float(worker["skills"].get("construction",20)))
		var storage_factor := clampf(1.0-warehouse_pressure*0.55,0.35,1.0)
		var tool_factor := 1.0 + minf(0.30,float(industry_stock.get("tools",0.0))*0.03)
		production_efficiency = storage_factor*tool_factor
		batch["progress"] = float(batch["progress"]) + sim_hours*(0.8+skill/100.0)*6.0*production_efficiency
		if float(batch["progress"]) >= float(recipe["work"]):
			_finish_batch(sim,batch,recipe)
		completed_lines += 1

func _consume_inputs(sim:SettlementSimulation, inputs:Dictionary) -> bool:
	for key in inputs.keys():
		var required := float(inputs[key])
		if key == "scrap" and float(sim.stockpiles["industry"].get("scrap",0.0)) < required:
			return false
		if key == "materials" and float(sim.stockpiles["industry"].get("materials",0.0)) < required:
			return false
		if key in industry_stock and float(industry_stock[key]) < required:
			return false
		if key == "repair_kits" and repair_kits < required:
			return false
	for key in inputs.keys():
		var required := float(inputs[key])
		if key == "scrap":
			sim.stockpiles["industry"]["scrap"] -= required
		elif key == "materials":
			sim.stockpiles["industry"]["materials"] -= required
		elif key in industry_stock:
			industry_stock[key] -= required
		elif key == "repair_kits":
			repair_kits -= required
	return true

func _finish_batch(sim:SettlementSimulation,batch:Dictionary,recipe:Dictionary) -> void:
	batch["status"] = "complete"
	for key in recipe["output"].keys():
		if key == "repair_kits":
			repair_kits += float(recipe["output"][key])
		else:
			industry_stock[key] = float(industry_stock.get(key,0.0)) + float(recipe["output"][key])
	sim.add_event("PRODUCTION COMPLETE","%s batch completed." % batch["recipe"],"good")

func _update_warehouse(sim:SettlementSimulation) -> void:
	var storage_modules := 0
	for building in sim.buildings:
		if building["type"] == "storage":
			storage_modules += 1
	warehouse_capacity = 100.0 + storage_modules*80.0
	warehouse_used = (
		float(sim.stockpiles["industry"].get("materials",0.0)) +
		float(sim.stockpiles["industry"].get("scrap",0.0)) +
		float(industry_stock.get("fuel",0.0))*0.8 +
		float(industry_stock.get("parts",0.0))*2.0 +
		float(industry_stock.get("tools",0.0))*2.5 +
		float(industry_stock.get("components",0.0))
	)
	warehouse_pressure = clampf((warehouse_used-warehouse_capacity)/maxf(1.0,warehouse_capacity),0.0,1.0)

	if sim.total_hours >= next_warehouse_check_hour:
		next_warehouse_check_hour = sim.total_hours + 24.0
		fuel_consumed_today = 0.0
		if warehouse_pressure > 0.0:
			var loss := minf(float(sim.stockpiles["industry"].get("materials",0.0)),2.0+warehouse_pressure*5.0)
			sim.stockpiles["industry"]["materials"] -= loss
			sim.add_event("WAREHOUSE OVERFLOW","Poor storage conditions ruined %.0f materials." % loss,"warning")

func consume_generator_fuel(sim:SettlementSimulation, sim_hours:float, generator_count:int) -> float:
	if generator_count <= 0:
		return 1.0
	var required := float(generator_count)*0.12*sim_hours
	var available := float(industry_stock.get("fuel",0.0))
	if available >= required:
		industry_stock["fuel"] = available-required
		fuel_consumed_today += required
		return 1.0
	if available > 0.0:
		var factor := clampf(available/maxf(required,0.001),0.1,1.0)
		industry_stock["fuel"] = 0.0
		fuel_consumed_today += available
		return factor
	return 0.08

func get_logistics_multiplier(sim_hours:float) -> float:
	for vehicle in vehicles:
		if not vehicle["operational"]:
			continue
		if float(vehicle["condition"]) <= 20.0:
			continue
		var required := 0.035*sim_hours
		var onboard := float(vehicle["fuel"])
		if onboard < required and float(industry_stock.get("fuel",0.0)) > 0.0:
			var transfer := minf(4.0,float(industry_stock["fuel"]))
			industry_stock["fuel"] -= transfer
			vehicle["fuel"] = onboard+transfer
			onboard = float(vehicle["fuel"])
		if onboard >= required:
			vehicle["fuel"] = onboard-required
			fuel_consumed_today += required
			return 1.75
	return 1.0

func repair_vehicle(sim:SettlementSimulation, vehicle_index:int=0) -> bool:
	if vehicle_index < 0 or vehicle_index >= vehicles.size():
		return false
	if repair_kits < 1.0:
		sim.add_event("VEHICLE REPAIR BLOCKED","A vehicle repair kit is required.","warning")
		return false
	var vehicle:Dictionary = vehicles[vehicle_index]
	repair_kits -= 1.0
	vehicle["condition"] = minf(100.0,float(vehicle["condition"])+35.0)
	vehicle["operational"] = true
	sim.add_event("VEHICLE REPAIRED","%s returned to service." % vehicle["name"],"good")
	return true

func _update_market(sim:SettlementSimulation) -> void:
	if sim.total_hours < price_update_hour:
		return
	price_update_hour = sim.total_hours + 24.0
	var pop := maxf(1.0,float(sim.get_settlement_citizens().size()))
	var ratios := {
		"food":float(sim.resources["food"])/(pop*8.0),
		"water":float(sim.resources["water"])/(pop*12.0),
		"medicine":float(sim.resources["medicine"])/(pop*1.5),
		"materials":float(sim.resources["materials"])/(pop*5.0),
		"scrap":float(sim.resources["scrap"])/(pop*6.0),
		"fuel":float(industry_stock["fuel"])/(pop*2.0),
		"parts":float(industry_stock["parts"])/(pop*1.0)
	}
	for key in ratios.keys():
		var scarcity := clampf(1.8-float(ratios[key]),0.55,2.5)
		var trade_modifier := clampf(1.0+float(trade_pressure.get(key,0.0))*0.06,0.7,1.4)
		var target := scarcity*trade_modifier
		market_index[key] = move_toward(float(market_index[key]),target,0.18)
		trade_pressure[key] = move_toward(float(trade_pressure.get(key,0.0)),0.0,0.35)

func trade(sim:SettlementSimulation,item:String,quantity:float,buying:bool) -> bool:
	if not market_index.has(item) or quantity <= 0.0:
		return false
	var unit_price := 10.0*float(market_index[item])
	var total := unit_price*quantity
	if buying:
		if credits < total:
			return false
		if item in ["fuel","parts"]:
			industry_stock[item] = float(industry_stock[item])+quantity
		elif item in sim.stockpiles["industry"]:
			sim.stockpiles["industry"][item] = float(sim.stockpiles["industry"][item])+quantity
		elif item in sim.stockpiles["command"]:
			sim.stockpiles["command"][item] = float(sim.stockpiles["command"][item])+quantity
		elif item == "medicine":
			sim.stockpiles["medical"]["medicine"] = float(sim.stockpiles["medical"]["medicine"])+quantity
		else:
			return false
		credits -= total
		trade_pressure[item] = float(trade_pressure.get(item,0.0))+quantity
	else:
		if not _remove_trade_item(sim,item,quantity):
			return false
		credits += total*0.8
		trade_pressure[item] = float(trade_pressure.get(item,0.0))-quantity
	trade_log.push_front({"item":item,"quantity":quantity,"buying":buying,"price":unit_price,"day":sim.day})
	if trade_log.size()>20:
		trade_log.resize(20)
	sim.add_event("TRADE COMPLETE","%s %.0f %s at %.1f credits/unit." % ["Bought" if buying else "Sold",quantity,item,unit_price],"good")
	return true

func _remove_trade_item(sim:SettlementSimulation,item:String,quantity:float) -> bool:
	if item in industry_stock:
		if float(industry_stock[item]) < quantity:
			return false
		industry_stock[item] -= quantity
		return true
	if item in sim.stockpiles["industry"]:
		if float(sim.stockpiles["industry"][item]) < quantity:
			return false
		sim.stockpiles["industry"][item] -= quantity
		return true
	if item in sim.stockpiles["command"]:
		if float(sim.stockpiles["command"][item]) < quantity:
			return false
		sim.stockpiles["command"][item] -= quantity
		return true
	if item == "medicine":
		if float(sim.stockpiles["medical"]["medicine"]) < quantity:
			return false
		sim.stockpiles["medical"]["medicine"] -= quantity
		return true
	return false

func _update_vehicle_state(sim:SettlementSimulation, sim_hours:float) -> void:
	for vehicle in vehicles:
		if not vehicle["operational"]:
			continue
		vehicle["condition"] = maxf(0.0,float(vehicle["condition"])-0.0022*sim_hours)
		if float(vehicle["condition"]) <= 15.0:
			vehicle["operational"] = false
			sim.add_event("VEHICLE OUT OF SERVICE","%s requires a repair kit." % vehicle["name"],"warning")

func get_active_batch() -> Dictionary:
	for batch in production_queue:
		if batch["status"] != "complete":
			return batch
	return {}


func _update_regional_trade(sim:SettlementSimulation, sim_hours:float) -> void:
	for market_key in regional_markets.keys():
		var market:Dictionary = regional_markets[market_key]
		var location := sim.world_simulation.get_location_by_id(int(market["location_id"]))
		if location.is_empty() or not location["discovered"]:
			continue
		if sim.total_hours >= float(market["next_caravan_hour"]) and not _market_has_active_caravan(str(market_key)):
			_spawn_trade_caravan(sim,str(market_key),location)

	for caravan in trade_caravans:
		if caravan["status"] in ["complete","lost"]:
			continue
		match str(caravan["status"]):
			"inbound":
				caravan["progress"] = float(caravan["progress"]) + 32.0*sim_hours
				if not caravan["risk_resolved"] and float(caravan["progress"]) >= float(caravan["distance"])*0.45:
					caravan["risk_resolved"] = true
					if sim.rng.randf() < float(caravan["route_danger"])*0.18:
						caravan["status"] = "lost"
						var market:Dictionary = regional_markets[str(caravan["market_key"])]
						market["next_caravan_hour"] = sim.total_hours + 120.0
						sim.add_event("TRADE CARAVAN LOST","A %s caravan failed to reach Last Haven." % caravan["faction"],"warning")
						continue
				if float(caravan["progress"]) >= float(caravan["distance"]):
					caravan["status"] = "trading"
					caravan["trade_hours_remaining"] = 36.0
					sim.add_event("TRADE CARAVAN ARRIVED","%s traders opened a 36-hour market at Last Haven." % caravan["faction"],"good")
			"trading":
				caravan["trade_hours_remaining"] = maxf(0.0,float(caravan["trade_hours_remaining"])-sim_hours)
				if float(caravan["trade_hours_remaining"]) <= 0.0:
					caravan["status"] = "returning"
					caravan["progress"] = 0.0
					sim.add_event("CARAVAN DEPARTED","%s traders closed market and began the return route." % caravan["faction"],"intel")
			"returning":
				caravan["progress"] = float(caravan["progress"]) + 32.0*sim_hours
				if float(caravan["progress"]) >= float(caravan["distance"]):
					caravan["status"] = "complete"
					var market:Dictionary = regional_markets[str(caravan["market_key"])]
					market["stock"] = caravan["stock"].duplicate(true)
					market["next_caravan_hour"] = sim.total_hours + 144.0

func _market_has_active_caravan(market_key:String) -> bool:
	for caravan in trade_caravans:
		if str(caravan["market_key"]) == market_key and caravan["status"] not in ["complete","lost"]:
			return true
	return false

func _spawn_trade_caravan(sim:SettlementSimulation, market_key:String, location:Dictionary) -> void:
	var market:Dictionary = regional_markets[market_key]
	var distance := Vector2(location["position"]).distance_to(Vector2(600,410))
	trade_caravans.append({
		"id":next_caravan_id,
		"market_key":market_key,
		"faction":market["faction"],
		"origin_location_id":int(market["location_id"]),
		"distance":distance,
		"progress":0.0,
		"status":"inbound",
		"route_danger":float(location.get("danger",0.25)),
		"risk_resolved":false,
		"trade_hours_remaining":0.0,
		"stock":market["stock"].duplicate(true),
		"credits":260.0
	})
	next_caravan_id += 1
	market["next_caravan_hour"] = sim.total_hours + 99999.0
	sim.add_event("CARAVAN INBOUND","Radio traffic confirms a %s trade caravan is approaching." % market["faction"],"intel")

func get_trade_sources() -> Array[Dictionary]:
	var sources:Array[Dictionary] = [{"kind":"local","name":"LOCAL MARKET","caravan_id":0}]
	for caravan in trade_caravans:
		if caravan["status"] == "trading":
			sources.append({
				"kind":"caravan",
				"name":"%s CARAVAN" % caravan["faction"].to_upper(),
				"caravan_id":int(caravan["id"])
			})
	return sources

func get_trade_price(item:String, source_index:int=0) -> float:
	if not market_index.has(item):
		return 0.0
	var base := 10.0*float(market_index[item])
	if source_index <= 0:
		return base
	var sources := get_trade_sources()
	if source_index >= sources.size():
		return base
	var caravan := get_caravan_by_id(int(sources[source_index]["caravan_id"]))
	if caravan.is_empty():
		return base
	var market:Dictionary = regional_markets[str(caravan["market_key"])]
	var modifier := float(market["price_modifiers"].get(item,1.0))
	var reputation_discount := clampf(float(market["reputation"])*0.0025,0.0,0.18)
	return base*modifier*(1.0-reputation_discount)

func trade_with_source(sim:SettlementSimulation, source_index:int, item:String, quantity:float, buying:bool) -> bool:
	if source_index <= 0:
		return trade(sim,item,quantity,buying)
	var sources := get_trade_sources()
	if source_index >= sources.size():
		return false
	var caravan := get_caravan_by_id(int(sources[source_index]["caravan_id"]))
	if caravan.is_empty() or caravan["status"] != "trading":
		return false
	if not market_index.has(item) or quantity <= 0.0:
		return false

	var unit_price := get_trade_price(item,source_index)
	var total := unit_price*quantity
	var caravan_stock:Dictionary = caravan["stock"]
	if buying:
		if credits < total or float(caravan_stock.get(item,0.0)) < quantity:
			return false
		if not _add_trade_item(sim,item,quantity):
			return false
		caravan_stock[item] = float(caravan_stock.get(item,0.0))-quantity
		credits -= total
		caravan["credits"] = float(caravan["credits"])+total
	else:
		if float(caravan["credits"]) < total*0.8:
			return false
		if not _remove_trade_item(sim,item,quantity):
			return false
		caravan_stock[item] = float(caravan_stock.get(item,0.0))+quantity
		credits += total*0.8
		caravan["credits"] = float(caravan["credits"])-total*0.8

	var market:Dictionary = regional_markets[str(caravan["market_key"])]
	market["reputation"] = minf(100.0,float(market["reputation"])+0.35*quantity)
	trade_log.push_front({
		"item":item,
		"quantity":quantity,
		"buying":buying,
		"price":unit_price,
		"day":sim.day,
		"source":caravan["faction"]
	})
	if trade_log.size()>20:
		trade_log.resize(20)
	sim.add_event("REGIONAL TRADE","%s %.0f %s with %s." % ["Bought" if buying else "Sold",quantity,item,caravan["faction"]],"good")
	return true

func _add_trade_item(sim:SettlementSimulation,item:String,quantity:float) -> bool:
	if item in ["fuel","parts"]:
		industry_stock[item] = float(industry_stock.get(item,0.0))+quantity
		return true
	if item in sim.stockpiles["industry"]:
		sim.stockpiles["industry"][item] = float(sim.stockpiles["industry"][item])+quantity
		return true
	if item in sim.stockpiles["command"]:
		sim.stockpiles["command"][item] = float(sim.stockpiles["command"][item])+quantity
		return true
	if item == "medicine":
		sim.stockpiles["medical"]["medicine"] = float(sim.stockpiles["medical"]["medicine"])+quantity
		return true
	return false

func get_caravan_by_id(id:int) -> Dictionary:
	for caravan in trade_caravans:
		if int(caravan["id"]) == id:
			return caravan
	return {}

func get_inbound_caravans() -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	for caravan in trade_caravans:
		if caravan["status"] in ["inbound","trading","returning"]:
			result.append(caravan)
	return result
