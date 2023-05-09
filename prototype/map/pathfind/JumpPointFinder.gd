extends Node

# @author imor / https://github.com/imor
# ported to gdscript by rafaelcastrocouto


# Finder glocal class

# This class is an Autoload accessible globally
# Access the autoload list in godot settings


const HeapGD = preload("Heap.gd")
const GridGD = preload("Grid.gd")


class JumpPointFinder:
	var Heap = HeapGD.Heap
	var openList
	var startNode
	var endNode
	var grid
	var OnlyWhenNoObstacles = 4
	var heuristic = "euclidean"
	
	func euclidean(dx, dy):
		return sqrt(dx * dx + dy * dy)
	
#/**
# * Find and return the path.
# * @return {Array<Array<number>>} The path, including both start and
# *     end positions.
# */
		
	func findPath(startX, startY, endX, endY, _grid):
		openList = Heap.new("jpfCmp")
		startNode = _grid.getNodeAt(startX, startY)
		endNode = _grid.getNodeAt(endX, endY)
		grid = _grid
		var node
		
		# set the `g` and `f` value of the start node to be 0
		startNode.g = 0
		startNode.f = 0
		
		# push the start node into the open list
		openList.push(startNode)
		startNode.opened = true
		
		# while the open list is not empty
		while (!openList.is_empty()):
			# pop the position of node which has the minimum `f` value.
			node = openList.pop()
			
			node.closed = true
			
			if (node == endNode):
				return expandPath(_backtrace(endNode))
			
			_identifySuccessors(node)
		
		# fail to find the path
		return []
	
#/**
# * Identify successors for the given node. Runs a jump point search in the
# * direction of each available neighbor, adding any points found to the open
# * list.
# * @protected
# */
	func _identifySuccessors(node):
		var endX = endNode.x
		var endY = endNode.y
		var neighbors
		var jumpPoint
		var x = node.x
		var y = node.y
		var jx = 0
		var jy = 0
		var ng = 0
		var jumpNode
		
		neighbors = findNeighbors(node)
		
		for neighbor in neighbors:
			jumpPoint = jump(neighbor[0], neighbor[1], x, y)
			if (jumpPoint):
			
				jx = jumpPoint[0]
				jy = jumpPoint[1]
				jumpNode = grid.getNodeAt(jx, jy)
				
				if (jumpNode.closed):
					continue
			
				# include distance, as parent may not be immediately adjacent:
				var d = call(heuristic, abs(jx - x), abs(jy - y))
				
				ng = node.g + d # next `g` value
				
				if (!jumpNode.opened or ng < jumpNode.g):
					jumpNode.g = ng
					if not jumpNode.h:
						jumpNode.h = call(heuristic, abs(jx - endX), abs(jy - endY))
						
					jumpNode.f = jumpNode.g + jumpNode.h
					jumpNode.parent = node
					
					if (!jumpNode.opened):
						openList.push(jumpNode)
						jumpNode.opened = true
					else:
						openList.updateItem(jumpNode)
	
	
# * Search recursively in the direction (parent -> child), 
#   stopping only when a jump point is found.
#   @return {Array<Array<number>>}
# * The x, y coordinate of the jump point found, or null if not found
	
	func jump(x, y, px, py):
		var dx = x - px
		var dy = y - py
		
		if (!grid.isWalkableAt(x, y)):
			return null
		
		
		if (grid.getNodeAt(x, y) == endNode):
			return [x, y]
		
		
		# check for forced neighbors
		# along the diagonal
		if (dx != 0 and dy != 0):
			# when moving diagonally, must check for 
			# vertical/horizontal jump points
			if (jump(x + dx, y, x, y) or jump(x, y + dy, x, y)):
				return [x, y]
		
		# horizontally/vertically
		else:
			if (dx != 0):
				if ((grid.isWalkableAt(x, y - 1) and !grid.isWalkableAt(x - dx, y - 1)) or
						(grid.isWalkableAt(x, y + 1) and !grid.isWalkableAt(x - dx, y + 1))):
					return [x, y]
			
			elif (dy != 0):
				if ((grid.isWalkableAt(x - 1, y) and !grid.isWalkableAt(x - 1, y - dy)) or
						(grid.isWalkableAt(x + 1, y) and !grid.isWalkableAt(x + 1, y - dy))):
					return [x, y]
		
		
		# moving diagonally, must make sure one of the vertical/horizontal
		# neighbors is open to allow the path
		if (grid.isWalkableAt(x + dx, y) and grid.isWalkableAt(x, y + dy)):
			return jump(x + dx, y + dy, x, y)
		else:
			return null
	
	
	# * Find the neighbors for the given node. If the node has a parent,
	#   prune the neighbors based on the jump point search algorithm, otherwise
	#   return all available neighbors.
	#   @return {Array<Array<number>>}
	# * The neighbors found.
	
	func findNeighbors(node):
		var parent = node.parent
		var x = node.x
		var y = node.y
		var px
		var py
		var dx
		var dy
		var neighbors = []
		var neighborNodes
		
		# directed pruning: can ignore most neighbors, unless forced.
		if (parent):
			px = parent.x
			py = parent.y
			# get the normalized direction of travel
			dx = (x - px) / max(abs(x - px), 1)
			dy = (y - py) / max(abs(y - py), 1)
			
			# search diagonally
			if (dx != 0 and dy != 0):
				if (grid.isWalkableAt(x, y + dy)):
					neighbors.append([x, y + dy])
				
				if (grid.isWalkableAt(x + dx, y)):
					neighbors.append([x + dx, y])
				
				if (grid.isWalkableAt(x, y + dy) 
						and grid.isWalkableAt(x + dx, y)):
					neighbors.append([x + dx, y + dy])
			
			
			# search horizontally/vertically
			else:
				var isNextWalkable
				if (dx != 0):
					isNextWalkable = grid.isWalkableAt(x + dx, y)
					var isTopWalkable = grid.isWalkableAt(x, y + 1)
					var isBottomWalkable = grid.isWalkableAt(x, y - 1)
					
					if (isNextWalkable):
						neighbors.append([x + dx, y])
						if (isTopWalkable):
							neighbors.append([x + dx, y + 1])
						
						if (isBottomWalkable):
							neighbors.append([x + dx, y - 1])
					
					if (isTopWalkable):
						neighbors.append([x, y + 1])
					
					if (isBottomWalkable):
						neighbors.append([x, y - 1])
					
				elif (dy != 0):
					isNextWalkable = grid.isWalkableAt(x, y + dy)
					var isRightWalkable = grid.isWalkableAt(x + 1, y)
					var isLeftWalkable = grid.isWalkableAt(x - 1, y)
					
					if (isNextWalkable):
						neighbors.append([x, y + dy])
						if (isRightWalkable):
							neighbors.append([x + 1, y + dy])
						
						if (isLeftWalkable):
							neighbors.append([x - 1, y + dy])
					
					if (isRightWalkable):
						neighbors.append([x + 1, y])
					
					if (isLeftWalkable):
						neighbors.append([x - 1, y])
		
		# return all neighbors
		else:
			neighborNodes = grid.getNeighbors(node, OnlyWhenNoObstacles)
			for neighborNode in neighborNodes:
				neighbors.append([neighborNode.x, neighborNode.y])
		
		return neighbors


#	 /**
#	 * Backtrace according to the parent records and return the path.
#	 * (including both start and end nodes)
#	 * @param {Node} node End node
#	 * @return {Array<Array<number>>} the path
#	 */
	func _backtrace(node):
		var path = [[node.x, node.y]]
		while (node.parent):
			node = node.parent
			path.append([node.x, node.y])
		path.reverse()
		return path
	
	
#		/**
#		* Given a compressed path, return a new path that has all the segments
#		* in it interpolated.
#		* @param {Array<Array<number>>} path The path
#		* @return {Array<Array<number>>} expanded path
#		*/
	func expandPath(path):
		var expanded = []
		var size = path.size()
		var coord0
		var coord1
		var interpolated
		var interpolatedLen
		
		if (size < 2):
			return expanded
		
		for i in range(size-1):
			coord0 = path[i]
			coord1 = path[i + 1]
			
			interpolated = _interpolate(coord0[0], coord0[1], coord1[0], coord1[1])
			interpolatedLen = interpolated.size()
			for j in range(interpolatedLen - 1):
				expanded.append(interpolated[j])
		
		expanded.append(path[size - 1])
		
		return expanded
	
	
#	/**
#	 * Given the start and end coordinates, return all the coordinates lying
#	 * on the line formed by these coordinates, based on Bresenham's algorithm.
#	 * http://en.wikipedia.org/wiki/Bresenham's_line_algorithm#Simplification
#	 * @param {number} x0 Start x coordinate
#	 * @param {number} y0 Start y coordinate
#	 * @param {number} x1 End x coordinate
#	 * @param {number} y1 End y coordinate
#	 * @return {Array<Array<number>>} The coordinates on the line
#	 */
	func _interpolate(x0, y0, x1, y1):
		var line = []
		var sx
		var sy
		var dx
		var dy
		var err
		var e2
		
		dx = abs(x1 - x0)
		dy = abs(y1 - y0)
		
		sx = 1 if x0 < x1 else -1
		sy = 1 if y0 < y1 else -1
		
		err = dx - dy;
		
		while (true):
			line.append([x0, y0])
			
			if (x0 == x1 and y0 == y1):
				break
			
			e2 = 2 * err
			if (e2 > -dy):
				err = err - dy
				x0 = x0 + sx
			
			if (e2 < dx):
				err = err + dx
				y0 = y0 + sy
		
		return line;
	
	
