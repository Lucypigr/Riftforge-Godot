extends RefCounted
## Phase 8 compact ARPG inventory: 180 real cells in one dense, POE-inspired grid.
const COLS := 18
const ROWS := 10
const PAGE_ROWS := 10
const PAGE_COUNT := 1

static func footprint(item: Dictionary) -> Vector2i:
	if item.has("grid_w") and item.has("grid_h"):
		return Vector2i(clampi(int(item["grid_w"]), 1, COLS), clampi(int(item["grid_h"]), 1, PAGE_ROWS))
	match str(item.get("slot", "")):
		"weapon", "armor", "shield": return Vector2i(2, 3)
		"helmet", "gloves", "boots": return Vector2i(2, 2)
		"ring", "amulet", "gem", "currency": return Vector2i.ONE
	return Vector2i.ONE

static func within_page(y: int, height: int) -> bool:
	return y >= 0 and y + height <= ROWS and (y % PAGE_ROWS) + height <= PAGE_ROWS

static func placed(item: Dictionary) -> bool:
	var size := footprint(item)
	var x := int(item.get("grid_x", -1))
	var y := int(item.get("grid_y", -1))
	return x >= 0 and x + size.x <= COLS and within_page(y, size.y)

static func can_place(items: Array, item: Dictionary, x: int, y: int, ignore_index: int = -1) -> bool:
	var size := footprint(item)
	if x < 0 or x + size.x > COLS or not within_page(y, size.y):
		return false
	for i in range(items.size()):
		if i == ignore_index:
			continue
		var other: Dictionary = items[i]
		if not placed(other):
			continue
		var o_size := footprint(other)
		var ox := int(other["grid_x"])
		var oy := int(other["grid_y"])
		if x < ox + o_size.x and x + size.x > ox and y < oy + o_size.y and y + size.y > oy:
			return false
	return true

static func try_add(items: Array, original: Dictionary) -> bool:
	var item := original.duplicate(true)
	item.erase("grid_x")
	item.erase("grid_y")
	for y in range(ROWS):
		for x in range(COLS):
			if can_place(items, item, x, y):
				item["grid_x"] = x
				item["grid_y"] = y
				items.append(item)
				return true
	return false

static func move(items: Array, index: int, x: int, y: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	var item: Dictionary = items[index]
	if not placed(item) or not can_place(items, item, x, y, index):
		return false
	item["grid_x"] = x
	item["grid_y"] = y
	items[index] = item
	return true

static func item_at(items: Array, x: int, y: int) -> int:
	for i in range(items.size()):
		var item: Dictionary = items[i]
		if not placed(item):
			continue
		var size := footprint(item)
		if x >= int(item["grid_x"]) and x < int(item["grid_x"]) + size.x and y >= int(item["grid_y"]) and y < int(item["grid_y"]) + size.y:
			return i
	return -1

static func occupied_cells(items: Array) -> int:
	var count := 0
	for item in items:
		if placed(item):
			var size := footprint(item)
			count += size.x * size.y
	return count

static func overflow_count(items: Array) -> int:
	var count := 0
	for item in items:
		if not placed(item):
			count += 1
	return count

static func normalize(items: Array) -> int:
	# Legacy saves keep valid cells. Overflow is retained, never deleted.
	var originals: Array = items.duplicate(true)
	var occupied: Array = []
	var accepted: Dictionary = {}
	for i in range(originals.size()):
		var item: Dictionary = originals[i]
		if placed(item) and can_place(occupied, item, int(item["grid_x"]), int(item["grid_y"])):
			occupied.append(item)
			accepted[i] = item
	var overflow := 0
	for i in range(originals.size()):
		if accepted.has(i):
			continue
		var item: Dictionary = originals[i]
		if try_add(occupied, item):
			accepted[i] = occupied.back()
		else:
			item["grid_x"] = -1
			item["grid_y"] = -1
			accepted[i] = item
			overflow += 1
	items.clear()
	for i in range(originals.size()):
		items.append(accepted[i])
	return overflow
