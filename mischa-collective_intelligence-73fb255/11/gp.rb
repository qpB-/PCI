# Ruby 1.9.1

class FunctionWrapper
	attr :name
	attr :function
	attr :childcount

	def initialize(childcount, name, &block)
		@function = block
		@childcount = childcount
		@name = name
	end
end

class Node

	attr_accessor :children

	def initialize(function_wrapper, children)
		@function = function_wrapper.function
		@name = function_wrapper.name
		@children = children	
	end

	def evaluate(input)
		results = @children.map{|n| n.evaluate(input)} #start at bottom
		@function.call(results)
	end
	
	def display(indent=0)
		puts(' ' * indent + @name)
		@children.each{|c| c.display(indent + 1)} 
		nil
	end
end

class ParamNode
	def initialize(index)
		@index = index
	end

	def evaluate(input)
		input[@index]
	end

	def display(indent=0)
		puts(' ' * indent + @index.to_s)
	end
end

class ConstNode
	def initialize(value)
		@value = value
	end

	def evaluate(input)
		@value
	end

	def display(indent=0)
		puts(' ' * indent + @value.to_s)
	end
end
class Functions

	ADDW = FunctionWrapper.new(2, 'add'){|l| l[0] + l[1]}
	SUBW = FunctionWrapper.new(2, 'subtract'){|l| l[0] - l[1]}
	MULW = FunctionWrapper.new(2, 'multiply'){|l| l[0] * l[1]}
	IFW = FunctionWrapper.new(3, 'if'){|l| l[0] ? l[1] : l[2]}
	GTW = FunctionWrapper.new(2, 'isgreater'){|l| l[0] > l[1] ? 1 : 0}

	LIST = [ADDW, SUBW, MULW, IFW, GTW]

	def self.example_tree
		Node.new(IFW, [
			Node.new(GTW, [ParamNode.new(0), ConstNode.new(3)]),
			Node.new(ADDW, [ParamNode.new(1), ConstNode.new(5)]),
			Node.new(SUBW, [ParamNode.new(1), ConstNode.new(2)])
		])
	end

end

class RandomTree

	# pc = param count
	# fpr = probability that it will be a function
	# ppr = probability that will be be param node if not function node
	def self.make(pc, options={})
		options[:maxdepth] ||= 4
		options[:fpr] ||= 0.5
		options[:ppr] ||= 0.6

		if rand < options[:fpr] && options[:maxdepth] > 0
			f = Functions::LIST[rand(Functions::LIST.size - 1)]

			children = [*(0..f.childcount - 1)].map do |i|
				RandomTree.make(pc, :maxdepth => options[:maxdepth] - 1,
												:fpt => options[:fpr], :ppr => options[:ppr])
			end
			
			Node.new(f, children)
		elsif rand < options[:ppr]
			ParamNode.new(rand(pc-1))
		else
			ConstNode.new(rand(10))
		end
	end


end

def hidden_function(x,y)
	x**2+2*y+3*x+5
end


def build_hidden_set()
	[*0..200].inject([]) do |array, i|
		x = rand(40)
		y = rand(40)
		array << [x, y, hidden_function(x,y)]	
	end
end

def score(tree, s)
	dif = 0
	s.each do |data|
		v = tree.evaluate([data[0], data[1]])
		dif += (v - data[2]).abs
	end
	
	dif
end

def deep_copy(obj)
	Marshal::load(Marshal.dump(obj))  
end

def mutate(t, pc, probchange=0.1)
	if rand < probchange
		RandomTree.make(pc)
	else
		result = t.clone
		if t.is_a?(Node)
			result.children = t.children.map{|c| mutate(c, pc, probchange)}
		end
		result
	end
end


def crossover(t1, t2, probswap=0.7, top=true)
	if rand < probswap && !top
		t2.clone
	else
		result = t1.clone
		if t1.is_a?(Node) && t2.is_a?(Node)
			result.children = t1.children.map do |c|
				crossover(c, t2.children[t2.children.length - 1], probswap, false)
			end
		end
		result
	end
		
end

# possible off by 1 w/ is greater 

def selectindex(pexp)
	(Math.log(rand) / Math.log(pexp)).to_i
end

def evolve(pc, popsize, rankfunction, options={})
	maxgen = options[:maxgen] || 500
	mutationrate = options[:mutationrate] || 0.1
	breedingrate = options[:breedingrate] || 0.4
	pexp = options[:pexp] || 0.7
	pnew = options[:pnew] || 0.05	


	population = [*0..popsize - 1].map{ RandomTree.make(pc)}
	scores = 0
	[*0..maxgen].map do |i|
		scores = send(rankfunction, population)
		puts scores[0][0]
		break if scores[0][0] == 0

		newpop = [scores[0][1], scores[1][1]]

		while newpop.length < popsize
			if rand > pnew
				cross = crossover(scores[selectindex(pexp)][1], scores[selectindex(pexp)][1], breedingrate)

				newpop << mutate(cross, pc, mutationrate)
			else
				newpop << RandomTree.make(pc)
			end
		end
		population = newpop
	end
	scores[0][1].display
	scores[0][1]
end

def rankfunction(population)
	dataset = build_hidden_set
	scores = population.map{|t| [score(t, dataset ), t]}
	scores.sort{|s| s[0][0]}
	scores
end

#evolve(1, 1, "rankfunction", :mutationrate => 0.2, :breedingrate => 0.1, :pexp => 0.7, :pnew => 0.1)
evolve(2, 500, "rankfunction", :mutationrate => 0.2, :breedingrate => 0.1, :pexp => 0.7, :pnew => 0.1)
