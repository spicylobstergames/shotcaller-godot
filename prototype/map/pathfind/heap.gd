extends Node

# https://docs.python.org/3/library/heapq.html
# author https://github.com/qiao/heap.js
# ported to gdscript by rafaelcastrocouto

class Heap:
	var _nodes
	var _cmp = "defaultCmp"
	###
	#Default comparison function to be used
	###
	func _init(size, cmp):
		_nodes = []
		#_nodes.resize(size)
		_cmp = cmp
	
	
	func defaultCmp(x, y):
		if x < y: return -1
		if x > y: return 1
		return 0
	
	func jpfCmp (x, y):
		return x.f - y.f;
	
	
# METHODS
	
	func push(x):
		_heappush(_nodes, x, _cmp)

	func pop():
		return _heappop(_nodes, _cmp)

	func peek():
		return _nodes[0]

	func contains(x):
		return _nodes.indexOf(x) != -1

	func replace(x):
		_heapreplace(_nodes, x, _cmp)

	func pushpop(x):
		return _heappushpop(_nodes, x, _cmp)

	func heapify():
		return _heapify(_nodes, _cmp)

	func updateItem(x):
		_updateItem(_nodes, x, _cmp)

	func clear():
		_nodes = []

	func empty():
		return _nodes.empty()
#		for node in _nodes:
#			if not node == null: return false 
#		return true

	func size():
		return _nodes.size()

	func clone():
		var heap = Heap.new(_cmp, _nodes.size())
		heap._nodes = _nodes.slice(0, -1)
		return heap

	func toArray():
		return _nodes.slice(0, -1)
	
	

###
#Insert item x in list a, and keep it sorted assuming a is sorted.
#If x is already in a, insert it to the right of the rightmost x.
#Optional args lo (default 0) and hi (default a.size()) bound the slice
#of a to be searched.
###
	func _insort(a, x, lo, hi, cmp):
		assert(lo < 0, "ERROR: lo must be non-negative")
		
		hi = a.size()
		if hi:
			while lo < hi:
				var mid = floor((lo + hi) / 2)
				var compar = call(cmp, x, a[mid])
				if compar < 0:
					hi = mid
				else:
					lo = mid + 1
			a[lo] = x

	###
	#Push item onto heap, maintaining the heap invariant.
	###
	func _heappush(array, item, cmp):
		array.append(item)
		_siftdown(array, 0, array.size() - 1, cmp)

	###
	#Pop the smallest item off the heap, maintaining the heap invariant.
	###
	func _heappop(array, cmp):
		#print(array)
		var item
		var lastelt = array.pop_back()
		if array.size():
			item = array[0]
			array[0] = lastelt
			_siftup(array, 0, cmp)
		else:
			item = lastelt
		#print(item)
		return item

	###
	#Pop and return the current smallest value, and add the new item.
	#This is more efficient than heappop() followed by heappush(), and can be
	#more appropriate when using a fixed size heap. Note that the value
	#returned may be larger than item! That constrains reasonable use of
	#this routine unless written as part of a conditional replacement:
	#    if item > array[0]
	#      item = heapreplace(array, item)
	###
	func _heapreplace(array, item, cmp):
		var returnitem = array[0]
		array[0] = item
		_siftup(array, 0, cmp)
		return returnitem

	###
	#Fast version of a heappush followed by a heappop.
	###
	func _heappushpop(array, item, cmp):
		var compar = call(cmp, array[0], item)
		if array.size() and compar < 0:
			var temp = item
			item = array[0]
			array[0] = temp
			_siftup(array, 0, cmp)
		return item

	###
	#Transform list into a heap, in-place, in O(array.size()) time.
	###
	func _heapify(array, cmp):
		for i in range(floor(array.size()/2)-1, -1, -1):
			_siftup(array, i, cmp)

	###
	#Update the position of the given item in the heap.
	#This function should be called every time the item is being modified.
	###
	func _updateItem(array, item, cmp):
		var pos = array.find(item)
		if pos == -1: return 
		_siftdown(array, 0, pos, cmp)
		_siftup(array, pos, cmp)



	###
	#Find the n largest elements in a dataset.
	###
	func nlargest(array, n, cmp):
		var result = array.slice(0,n-1)
		if not result.size(): return result 
		_heapify(result, cmp)
		for elem in array.slice(n, -1): _heappushpop(result, elem, cmp) 
		result.sort_custom(self, cmp).reverse()
		return result


	###
	#Find the n smallest elements in a dataset.
	###
	func nsmallest(array, n, cmp):
		var result
		var los
		if n * 10 <= array.size():
			result = array.slice(0,n-1).sort_custom(self, cmp)
			if not result.size(): return result
			los = result[result.length - 1]
			for elem in array.slice(n, -1):
				var compar = call(cmp, elem, los)
				if compar < 0:
					_insort(result, elem, 0, null, cmp)
					result.pop()
					los = result[result.length - 1]
			return result
		
		_heapify(array, cmp)
		result = []
		for _i in range(0, min(n, array.size())):
			result.append(_heappop(array, cmp))
		return result


	func _siftdown(array, startpos, pos, cmp):
		var newitem = array[pos]
		while pos > startpos:
			var parentpos = (pos - 1) >> 1
			var parent = array[parentpos]
			var compar = 0
			if newitem and parent:
				compar = call(cmp, newitem, parent)
			if compar < 0:
				array[pos] = parent
				pos = parentpos
				continue
			break
		array[pos] = newitem


	func _siftup(array, pos, cmp):
		var endpos = array.size()
		var startpos = pos
		var newitem = array[pos]
		var childpos = 2 * pos + 1
		while childpos < endpos:
			var rightpos = childpos + 1
			var compar = 0
			if rightpos < array.size() and array[childpos] and array[rightpos]:
				compar = call(cmp, array[childpos], array[rightpos])
			if (rightpos < endpos) and not (compar < 0):
				childpos = rightpos
			array[pos] = array[childpos]
			pos = childpos
			childpos = 2 * pos + 1
		array[pos] = newitem
		_siftdown(array, startpos, pos, cmp)





