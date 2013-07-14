require 'rubygems'
require 'twitter'
require_relative 'twitter_bot'

account = ARGV[0]
args = ARGV.to_set
args.delete(account)


# consumer_file = IO.readlines("accounts/#{consumer}/authentication.txt")
account_file = IO.readlines("accounts/#{account}/authentication.txt")

consumer_key = account_file[0].strip
consumer_secret = account_file[1].strip
oauth_token = account_file[2].strip
oauth_token_secret = account_file[3].strip

@twitter_bot = TwitterBot.new(account, 
	consumer_key, consumer_secret, 
	oauth_token, oauth_token_secret)

@twitter_bot.print_client # Print our information about ourselves!

# if you want to whitelist all of the users you follow now
if args.include?("whitelist")
	puts "White listing our friends"
	@twitter_bot.write_to_file("whitelist", @twitter_bot.get_friend_id_array)
	print "\n\n"
end

# if you want to blacklist all of the users who follow you now
if args.include?("blacklist")
	puts "Blacklisting all of our followers"
	@twitter_bot.write_to_file("blacklist", @twitter_bot.get_follower_id_array)
	print "\n\n"
end

# if you want to follow all your followers
if args.include?("follow all followers")
	puts "Following all followers"
	@twitter_bot.follow_all_followers
	print "\n\n"
end

# if you want to dm all of your new followers
if args.include?("message")
	puts "Messaging all new followers"
	@twitter_bot.dm_new_followers
	print "\n\n"
end

# if you want to unfollow all of those who are not following you
if args.include?("unfollow all non followers")
	puts "Unfollowing non followers"
	@twitter_bot.unfollow_all_non_followers
	print "\n\n"
end

# if you want to unfollow everyone
if args.include?("unfollow everyone")
	puts "Unfollowing everyone"
	@twitter_bot.unfollow_everyone
	print "\n\n"
end

if args.include?("random from followers")
	num_followers_to_crawl = DEFAULT_NUM_FOLLOWERS_TO_CRAWL
	num_users_to_follow = DEFAULT_NUM_USERS_TO_FOLLOW
	puts "Following #{num_users_to_follow} followers of #{num_followers_to_crawl} random followers"
	@twitter_bot.follow_random(num_followers_to_crawl, num_users_to_follow)
	print "\n\n"
end

if args.include?("keywords")
	keyword_tweets_to_read = DEFAULT_KEYWORD_TWEETS_TO_READ
	puts "Following people who tweet about our keywords"
	@twitter_bot.follow_keywords(keyword_tweets_to_read)
	print "\n\n"
end

# to tweet from text file
if args.include?("tweet")
        puts "Tweeting from file"
        @twitter_bot.tweet
        print "\n\n"
end
