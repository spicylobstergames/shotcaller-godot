extends Node


# author https://github.com/qiao/PathFinding.js/blob/master/src/core/Grid.js
# ported to gdscript by rafaelcastrocouto

#
# * The Grid class, which serves as the encapsulation of the layout of the nodes.
# * @constructor
# * @param {number|Array<Array<(number|boolean)>>} width_or_matrix Number of columns of the grid, or matrix
# * @param {number} height Number of rows of the grid.
# * @param {Array<Array<(number|boolean)>>} [matrix] - A 0-1 matrix
# *     representing the walkable status of the nodes(0 or false for walkable).
# *     If the matrix is not supplied, all the nodes will be walkable. 
#

class Grid:
	var width
	var height
	var matrix
	var nodes
	
	var DiagonalMovement = {
		"Always": 1,
		"Never": 2,
		"IfAtMostOneObstacle": 3, # cross corners
		"OnlyWhenNoObstacles": 4  # don't cross corners
	}
	
	func _init(_width, _height, _matrix = []):
		
		if _matrix.size():
			_height = _matrix.size()
			_width = _matrix[0].size()
		#
		# * The number of columns of the grid.
		# * @type number
		#
		self.width = _width
		#
		# * The number of rows of the grid.
		# * @type number
		#
		self.height = _height
		
		#
		# * A 2D array of nodes.
		#
		self.nodes = _buildNodes()
	
	
#
# * Build and return the nodes.
# * @private
# * @param {number} width
# * @param {number} height
# * @param {Array<Array<number|boolean>>} [matrix] - A 0-1 matrix representing
# *     the walkable status of the nodes.
# * @see Grid
#
	func _buildNodes():
		var newNodes = []
		
		for i in range(height):
			newNodes.append([])
			for j in range(width):
				newNodes[i].append(GridNode.new(j, i, true))
		
		
		if (!matrix):
				return newNodes
		
		assert( matrix.size() != height or matrix[0].size() != width, "ERROR: Matrix size does not fit")
		
		
		for i in range(height):
			for j in range(width):
				if (matrix[i][j]):
					# 0, false, null will be walkable
					# while others will be un-walkable
					newNodes[i][j].walkable = false
		
		return newNodes
	
	
	
	func getNodeAt(x, y):
		return nodes[y][x]
	
	
#
# * Determine whether the node at the given position is walkable.
# * (Also returns false if the position is outside the grid.)
# * @param {number} x - The x coordinate of the node.
# * @param {number} y - The y coordinate of the node.
# * @return {boolean} - The walkability of the node.
#
	func isWalkableAt(x, y):
		return isInside(x, y) and nodes[y][x].walkable
	
#	
# * Determine whether the position is inside the grid.
# * XXX: `grid.isInside(x, y)` is wierd to read.
# * It should be `(x, y) is inside grid`, but I failed to find a better
# * name for this  method.
# * @param {number} x
# * @param {number} y
# * @return {boolean}
#
	func isInside(x, y):
		return (x >= 0 and x < width) and (y >= 0 and y < height)
	
#
# * Set whether the node on the given position is walkable.
# * NOTE: throws exception if the coordinate is not inside the grid.
# * @param {number} x - The x coordinate of the node.
# * @param {number} y - The y coordinate of the node.
# * @param {boolean} walkable - Whether the position is walkable.
#
	func setWalkableAt(x, y, walkable):
		nodes[y][x].walkable = walkable
	
#
# * Get the neighbors of the given node.
# *
# *     offsets      diagonalOffsets:
# *  +---+---+---+    +---+---+---+
# *  |   | 0 |   |    | 0 |   | 1 |
# *  +---+---+---+    +---+---+---+
# *  | 3 |   | 1 |    |   |   |   |
# *  +---+---+---+    +---+---+---+
# *  |   | 2 |   |    | 3 |   | 2 |
# *  +---+---+---+    +---+---+---+
# *
# *  When allowDiagonal is true, if offsets[i] is valid, then
# *  diagonalOffsets[i] and
# *  diagonalOffsets[(i + 1) % 4] is valid.
# * @param {GridNode} node
# * @param {DiagonalMovement} diagonalMovement
#
	func getNeighbors(node, diagonalMovement):
		var x = node.x
		var y = node.y
		var neighbors = []
		var s0 = false
		var d0 = false
		var s1 = false
		var d1 = false
		var s2 = false
		var d2 = false
		var s3 = false
		var d3 = false
		
		# ↑
		if (isWalkableAt(x, y - 1)):
			neighbors.append(nodes[y - 1][x])
			s0 = true
		
		# →
		if (isWalkableAt(x + 1, y)):
			neighbors.append(nodes[y][x + 1])
			s1 = true
		
		# ↓
		if (isWalkableAt(x, y + 1)):
			neighbors.append(nodes[y + 1][x])
			s2 = true
		
		# ←
		if (isWalkableAt(x - 1, y)):
			neighbors.append(nodes[y][x - 1])
			s3 = true
		
		
		if (diagonalMovement == DiagonalMovement.Never):
			return neighbors
		

		
		if (diagonalMovement == DiagonalMovement.OnlyWhenNoObstacles):
			d0 = s3 and s0
			d1 = s0 and s1
			d2 = s1 and s2
			d3 = s2 and s3
		elif (diagonalMovement == DiagonalMovement.IfAtMostOneObstacle):
			d0 = s3 or s0
			d1 = s0 or s1
			d2 = s1 or s2
			d3 = s2 or s3
		elif (diagonalMovement == DiagonalMovement.Always):
			d0 = true
			d1 = true
			d2 = true
			d3 = true
		
		
		# ↖
		if (d0 and isWalkableAt(x - 1, y - 1)):
			neighbors.append(nodes[y - 1][x - 1])
		
		# ↗
		if (d1 and isWalkableAt(x + 1, y - 1)):
			neighbors.append(nodes[y - 1][x + 1])
		
		# ↘
		if (d2 and isWalkableAt(x + 1, y + 1)):
			neighbors.append(nodes[y + 1][x + 1])
		
		# ↙
		if (d3 and isWalkableAt(x - 1, y + 1)):
			neighbors.append(nodes[y + 1][x - 1])
		
		
		return neighbors
	
	
#
# * Get a clone of this grid.
# * @return {Grid} Cloned grid.
#
	func clone():
		var newGrid = Grid.new(width, height, [])
		var newNodes = []
		
		for i in range(height):
			newNodes.append([])
			for j in range(width):
				var newNode = GridNode.new(j, i, nodes[i][j].walkable)
				newNodes[i].append(newNode)
		
		newGrid.nodes = newNodes
		
		return newGrid



# * A node in grid. 
# * This class holds some basic information about a node and custom 
# * attributes may be added, depending on the algorithms' needs.
# * @constructor
# * @param {number} x - The x coordinate of the node on the grid.
# * @param {number} y - The y coordinate of the node on the grid.
# * @param {boolean} [walkable] - Whether this node is walkable.
#
class GridNode:
	var x
	var y
	var walkable
	var f
	var g
	var h
	var opened
	var closed
	var parent
	
	func _init(_x, _y, _walkable):
		self.x = _x
		self.y = _y
		self.walkable = _walkable
		self.f = 0
		self.g = 0
		self.h = 0
		self.opened = false
		self.closed = false
