def getwords(doc)
	words = doc.scan(/\w*/).map{|w| w.downcase if w.length > 2 && w.length < 20}.compact!
	words.uniq
end

class Classifier
	attr :fc
	attr :cc

	def initialize(getfeatures, filename=nil)
		@fc = Hash.new{|h,k| h[k] = Hash.new{|h1,k1| h1[k1] = 0}} #hash of hashes of 0
		@cc = Hash.new{|h,k| h[k] = 0}
		@getfeatures = getfeatures
		@thresholds = Hash.new{|h,k| h[k] = 0}
	end

	def setthreshold(cat, t)
		@thresholds[cat] = t
	end

	def getthreshold(cat)
		@thresholds[cat] || 0
	end

	def incf(f, cat)
		@fc[f][cat] += 1
	end

	def incc(cat)
		@cc[cat] += 1
	end

	def fcount(f, cat)
		@fc[f][cat].to_f
	end

	def catcount(cat)
		@cc[cat].to_f
	end

	def totalcount
		@cc.values.inject(0){|m,o| m += o; m}
	end

	def categories
		@cc.keys
	end

	def train(item, category)
		features = @getfeatures.call(item)
		features.each {|f| incf(f, category)}

		incc(category)
	end

	def fprob(f, cat)
		return 0 if catcount(cat) == 0
		fcount(f, cat) / catcount(cat)
	end

	def weightedprob(f, cat, prf, weight=1.0, ap=0.5)
		basicprob = prf.call(f, cat)

		totals = categories.inject(0){|m, o| m += fcount(f, o); m}

		((weight * ap ) + (totals * basicprob))  / (weight + totals)
	end

	def classify(item, default='unknown')
		probs = {}

		max = 0.0
		best = 'hi'

		categories.each do |cat|
			probs[cat] = prob(item,cat)
			if probs[cat] > max
				max = probs[cat]
				best = cat
			end
		end

		probs.each do |cat, val|
			next if cat == best
			return default if probs[cat] * getthreshold(best) > probs[best]
		end
		
		best
	end

end

def sampletrain(cl)
	cl.train('Nobody owns the water.','good') 
	cl.train('the quick rabbit jumps fences','good') 
	cl.train('buy pharmaceuticals now','bad') 
	cl.train('make quick money at the online casino','bad') 
	cl.train('the quick brown fox jumps','good') 
end


class NaiveBayes < Classifier
	
	def docprob(item, cat)
		features = @getfeatures.call(item)

		p = 1	

		features.each {|f| p *= weightedprob(f, cat, lambda{|*args| self.fprob(*args)})}

		p
	end

	def prob(item, cat)
		catprob = catcount(cat) / totalcount
		docprob = docprob(item, cat)
		
		docprob * catprob
	end

end


def test
	@@getfeatures = lambda{|*args| getwords(*args)}
	test1
	test2
	test3
	test4
	test5
end

def test1
	cl = Classifier.new(@@getfeatures)
	cl.train('the quick brown fox jumps over the lazy dog', 'good')
	cl.train('make quick money in the online casino', 'bad')
	p cl.fcount('quick', 'good')
	puts "should be 1.0\n\n"
	p cl.fcount('quick', 'bad')
	puts "should be 1.0\n\n"
end

def test2
	cl = Classifier.new(@@getfeatures)
	sampletrain(cl)
	p cl.fprob('quick', 'good')
	p "should be 0.6666...3"
end

def test3
	cl = Classifier.new(@@getfeatures)
	sampletrain(cl)
	p cl.weightedprob('money', 'good', lambda{|*args| cl.fprob(*args)})
	puts "should be 0.25"

	sampletrain(cl)
	p cl.weightedprob('money', 'good', lambda{|*args| cl.fprob(*args)})
	puts "should be 0.166..."
end

def test4
	cl = NaiveBayes.new(@@getfeatures)
	sampletrain(cl)

	p cl.prob('quick rabbit', 'good')
	puts "should be 1.5624999...7"

	p cl.prob('quick rabbit', 'bad')
	puts("should be 0.05000...3")
end

def test5
	cl = NaiveBayes.new(@@getfeatures)
	sampletrain(cl)

	p cl.classify('quick rabbit')
	puts "should be good"

	p cl.classify('quick money')
	puts "should be bad"

	cl.setthreshold('bad', 3.0)

	p cl.classify('quick money')
	puts "should be unknown"

	10.times { sampletrain(cl) }

	p cl.classify('quick money')
	puts "should be bad"

end

