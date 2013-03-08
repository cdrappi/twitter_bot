require 'rubygems'
require 'twitter'
require_relative 'twitter_constants'

class TwitterBot
	# We define 'TwitterBot' to be a class with one attribute, a @client.
	# This client is a Twitter::Client.
	# Therefore, all methods I call from this class are called from 
	# the TwitterBot object, whereas the calls to the Twitter API come when I 
	# call a method of @client.
	def initialize(account, consumer_key, consumer_secret, 
					oauth_token, oauth_token_secret,
					options = {follow_limit: DEFAULT_FOLLOW_LIMIT,
					unfollow_limit: DEFAULT_UNFOLLOW_LIMIT,
					count_followed: DEFAULT_COUNT_FOLLOWED,
					count_unfollowed: DEFAULT_COUNT_UNFOLLOWED,
					sleep_mean: DEFAULT_SLEEP_MEAN, 
					sleep_spread: DEFAULT_SLEEP_SPREAD} )
		@sleep_mean = options[:sleep_mean]
		@sleep_spread = options[:sleep_spread]
		@client = Twitter::Client.new(
		  consumer_key: consumer_key,
		  consumer_secret: consumer_secret,
		  oauth_token: oauth_token,
		  oauth_token_secret: oauth_token_secret
		)
		@account = account
		@follower_ids = fetch_follower_id_array
		@friend_ids = fetch_friend_id_array
		@follow_limit = options[:follow_limit]
		@unfollow_limit = options[:unfollow_limit]
		@count_followed = 0
		@count_unfollowed = 0
		@whitelist = file_to_array("whitelist")
		@blacklist = file_to_array("blacklist")
		@keywords = file_to_array("keywords", true)
		@message = load_message
	end

	# here we get all the UIDs of our followers
	def fetch_follower_id_array
		follower_ids = hit_twitter { @client.follower_ids.to_a }
		return follower_ids
	end

	# here we get all the UIDs of those we follow - the twitter gem calls them "friends"
	def fetch_friend_id_array
		friend_ids = hit_twitter { @client.friend_ids.to_a }
		return friend_ids
	end

	def get_friend_id_array
		return @friend_ids
	end

	def get_follower_id_array
		return @follower_ids
	end

	def dm_new_followers(followers = @follower_ids)
		to_write = write_to_file("followers_messaged", followers)
		print "to_write: #{to_write}\n\n"
		to_write.each do |new_follower|
			hit_twitter { @client.direct_message_create(new_follower, @message) }
			puts "Sent message to #{new_follower}"
		end
	end

	def load_message
		message = File.open("#{self.get_account_path}message.txt")
		return message.readlines[0]
	end

	def get_account_path
		return "accounts/#{@account}/"
	end

	def get_username(id)
		username = hit_twitter { @client.user(id).screen_name }
	end

	def write_to_file(file, ids)
		# returns only the newly written ids
		# note that "file" is a file name (without extension - .txt)
		# and the directory is already taken care of
		to_write = ids - file_to_array(file)
		File.open("#{self.get_account_path}#{file}.txt", "a+") do |f|
			to_write.each do |id|
				f.puts "#{id}"
			end
		end
		return to_write
	end

	def file_to_array(file, str=false)
		res = Array.new
		File.open("#{self.get_account_path}#{file}.txt", "r+") do |f|
			f.each_line do |id|
				if str
					res.push(id.to_s.gsub("\n",""))
				else
					res.push(id.to_i)
				end
			end
		end
		return res
	end

	def hit_twitter
		# First, we give the Twitter servers a random break
		s = random_sleep(@sleep_mean, @sleep_spread)
		sleep s

		begin
  			yield 
  			# the code we wish to execute
  			# which is something that might break twitter
		rescue Twitter::Error::TooManyRequests => error
			@limit = error.rate_limit.limit
			@remaining = error.rate_limit.remaining
			@reset_at = error.rate_limit.reset_at
			@reset_in = error.rate_limit.reset_in
			puts("Rate limit: #{@limit}")
			puts("Hits remaining: #{@remaining}")
			puts("Resetting at: #{@reset_at}")
			puts("Sleeping for #{@reset_in}")
			sleep @reset_in
		end
	end

	def random_sleep(mean = DEFAULT_SLEEP_MEAN, spread = DEFAULT_SLEEP_SPREAD)
		distance_from_mean = rand(2*spread + 1) - spread+1
		return mean + distance_from_mean
	end

	def auto_follow_check
		# returns false <=> we hit our follow limit
		@count_followed = @count_followed + 1
		if @count_followed >= @follow_limit
			return false
		else
			return true
		end
	end
	
	def auto_unfollow_check
		# returns false <=> we hit our unfollow limit
		@count_unfollowed = @count_unfollowed + 1
		if @count_unfollowed >= @unfollow_limit
			return false
		else
			return true
		end
	end
			

	def follow_all_followers
		# Creates array of UIDs who follow us but we don't follow
		unfollowed_followers = @follower_ids - @friend_ids
		
		follow_array(unfollowed_followers)
	end

	def unfollow_all_non_followers
		# Creates array of UIDs that we follow but don't follow us
		non_followers = @friend_ids - @follower_ids
		
		unfollow_array(non_followers)
	end

	def unfollow_everyone
		puts "\n\n\nFRIEND IDS:\n#{@friend_ids}\n\n\n"
		unfollow_array(@friend_ids, true)
	end

	def follow_array(ids, max=false)
		# Follow up to max users on to_follow that we should_follow
		to_follow = ids - @friend_ids

		if max && max < to_follow.length
			to_follow = to_follow.sample(max)
		end

		to_follow.each do |f|
			if should_follow(f)
				hit_twitter { @client.follow(f) }
				puts "Followed: #{f}"
				unless self.auto_follow_check
					break
				end
			end
		end
	end

	def unfollow_array(to_unfollow)
		# Unfollow everyone on to_unfollow that we should_unfollow
		puts "to_unfollow\n#{to_unfollow}\n\n"
		to_unfollow.each do |f|
			if should_unfollow(f)
				hit_twitter { @client.unfollow(f) }
				puts "Unfollowed: #{f}"
				unless self.auto_unfollow_check
					break
				end
			end
		end
	end

	def print_client
		print "\n\nAccount: @#{@client.user.screen_name}\nTwitter id: #{@client.user.id}\n\n"
	end

	def follow_random(users_to_crawl=DEFAULT_USERS_TO_CRAWL, max_to_follow_per_user=DEFAULT_USERS_TO_FOLLOW)
	# follows max_to_follow_per_user random users that follow users_to_crawl one of our friends
		crawled_already = Array.new
		loops = [users_to_crawl, @follower_ids.length].min
		random_follower_id = nil
		random_follower = nil
		loops.times do
			# pick a random user id and get the user object
			loop do 
				# fetch a new user that we haven't fetched before, hopefully they aren't protected
				random_follower_id = (@follower_ids - crawled_already).sample
				random_follower = hit_twitter { @client.user(random_follower_id) }
				# make sure we don't get a protected user
				break unless hit_twitter { random_follower.protected? }
			end
			crawled_already.push(random_follower_id)
			follow_followers_of(random_follower_id, max_to_follow_per_user, random_follower)
		end
	end

	def follow_followers_of(id, max=false, user=false)
		unless user
			user = hit_twitter { @client.user(id) }
		end

		follower_ids = hit_twitter { @client.follower_ids(id).to_a }
		print "\n------------------------------------\n"
		print "Following followers of: @#{user.screen_name}, \nwho has #{follower_ids.size} followers"
		print "\n------------------------------------\n"
		follow_array(follower_ids, max)
	end

	def tweeting_keyword(keyword, max_tweets = DEFAULT_MAX_TWEETS)
		# returns UIDs tweeting about keyword
		results = hit_twitter { @client.search(keyword, {count: max_tweets}).statuses }
		tweeter_ids = Array.new
		results.each do |tweet|
			tweeter_ids.push(tweet.user.id)
		end
		return tweeter_ids
	end

	def follow_keywords(max_tweets = DEFAULT_MAX_TWEETS)
		puts "Keywords: #{@keywords}"
		@keywords.each do |keyword|
			puts "keyword: #{keyword}"
			to_follow = tweeting_keyword(keyword, max_tweets)
			puts "to_follow: #{to_follow}"
			follow_array(to_follow)
		end
	end

	def should_follow(id)
		if @blacklist.include?(id)
		# if the user's id is on our blacklist, don't follow them
			return false
		else
			return true
		end
	end

	def should_unfollow(id)
		if @whitelist.include?(id)
		# if the user's id is on our whitelist, don't unfollow them
			return false
		else
			return true
		end
	end

end