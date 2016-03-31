# HyperactiveRecord

**Note: This project doesn’t actually exist (yet?). I’ve just written this README in the hope that someone else finds it compelling enough to implement it. (Or maybe I'll implement it myself one day.)**

HyperactiveRecord is an ActiveRecord plugin. It lets you write ActiveRecord-like queries with a DSL which more closely imitates the experience of using normal objects.

In HyperStrict mode, it also bans you from directly calling relations. Eg you can’t call the comments method on a User object like you would in Rails; if you want to access your comments you have to do it from the HyperactiveQuery where you loaded that user. This makes n + 1 queries much harder to write accidentally. I’m not sure whether HyperStrict mode is a good idea.

## Examples

```ruby
# User includes the HyperactiveRecord plugin
# Starting out normal. Let's get the users have made a post.
users_with_posts = User.filter { |u| u.posts.length > 0 }

# Let's get the oldest 10 users who have made a post.
top_ten = User.filter { |u| !u.posts.empty? }.order_by(:created_at).limit(10)

# Let's make the previous query also include their most popular post.
class User
  # you can define relations like this
  hyper_define :most_popular_post do |user|
    user.posts.order_by { |post| post.comments.count }.first
  end
end

top_ten_with_most_popular_post = top_ten.include(:most_popular_post)

# By default, loading an object means loading all of its fields. We can instead
# only load some of the fields with only_load.

# All of our loaded users then have a most_popular_post field which is a Post
# which hasn't loaded any of its attributes except its title.

top_ten_with_most_popular_post_title = top_ten.include do |u|
  u.most_popular_post.only_load(:title)
end

# Let's get the average number of comments per post of a user.
class User
  hyper_define :average_number_of_comments_per_post
    user.posts.flat_map(:comments).count / user.posts.count
  end
end

# Let's load everything we need to make the show page on a blog.

@post = Post.find(params[:id]).include do |post|
  post.comments
  post.citations
  post.user.only_load(:name, :description, :avatar_url)

  # these next two lines are equivalent
  post.comments.flat_map(:user).only_load(:name, :avatar_url)
  post.comments.include { |c| c.flat_map(:user).only_load(:name, :avatar_url) }

  # suppose we want to display the number of edits for some reason, as post.edit_count
  post.edit_count post.edits.count
end
@user = @post.user

# I'm not sure yet whether that will evaluate eagerly or lazily. That
# affects the semantics of, for example, calling @user before you call @post.
```

## How does it work?

(Disclaimer: it doesn't; this software doesn't actually exist.)

It works the same way ActiveRecord does. I don't know a good word for the design pattern which this is embodying, but functional programmers would talk about how this reminds them of the idea of [free objects](https://en.wikipedia.org/wiki/Free_object) in abstract algebra. (They most regularly talk about free monads: this library does indeed define a free monad, sort of--it has `map` and `flat_map`, and I guess `find` does sort of look like the map `return :: a -> M a`.

## API

### HyperactiveModel

This inherits from ActiveModel and defines a bunch of cool new stuff.

### Class methods
#### `belongs_to(relation_name)`

same as in AR

#### `has_many(relation_name)`

same as in AR. You can't define `has_many :through` though. You should define that explicitly with `hyper_define`.

#### `hyper_define(:relation_name, &blk)`

This defines a method. `blk` is passed the model which is calling the method, followed by all function arguments.

This only works with some kinds of function arguments, obviously. Numbers are fine. I don't know what other kinds of arguments work. There's some kind of restriction on when things need to be constant, I don't know what it is, so sue me.

### Instance methods

#### `all`

returns all of them. (It's a monadic return!) This is just needed so that you can for example do `User.all.each`.

#### `filter(**conditions, &blk_conditions)`

filters down to having values which match the `conditions` hash and the `blk_conditions` block.

Examples:

```ruby
Post.filter(published: true) # all published posts
Post.filter { |p| p.comments.nonempty? } # all posts with a comment
Post.filter(published: true) { |p| p.comments.nonempty? } # all published posts with a comment
```


#### `map(field_name = nil, &blk)`

like in Ruby.

```ruby
User.posts.map(:title)

User.posts.map { |p| p.title.length + p.body.length }
```

#### `flat_map(field_name = nil, &blk)`

Examples:

```ruby
# like a has_many :through.
User.posts.flat_map(:comments)
```

#### `include(fields, &blk)`

Loads all of the fields specified in `blk`. Here's a slightly expanded version of the example above:

```ruby
@post = Post.find(params[:id]).include(:comments) do |post|
  # you could also load comments like this:
  post.comments

  post.user.only_load(:name, :description, :avatar_url)

  # these next two lines are equivalent
  post.comments.flat_map(:user).only_load(:name, :avatar_url)
  post.comments.include { |c| c.flat_map(:user).only_load(:name, :avatar_url) }

  # suppose we want to display the number of edits for some reason, as post.edit_count
  post.edit_count post.edits.count

  # and we want to show the average number of comments on this user's posts
  total_likes = post.user.posts.flat_map(:comments).count
  post.total_posts = post.user.posts.count
  post.average_number_of_comments total_likes / post.total_posts
end
```

So. Includes takes a list of relations and a block. The relations are all loaded. The block is evaluated. Inside the block, if you write a relation, that will be loaded. You can modify relations as always. You can load anything else you want by calling it with whatever other name, eg `total_posts` or `average_number_of_comments` above.

#### `order_by(*fields, **ordered_fields, &blk)`

Orders things.

Examples:

```ruby
# posts in ascending order of creation
Post.order_by(:created_at)

# posts in ascending order of length
# breaking ties with the earlier post coming first
Post.order_by(:length, :created_at)

# posts in ascending order of length
# breaking ties with the earlier post coming second
Post.order_by(:length, created_at: :desc)

# posts by number of comments, assuming you hyper_defined this
Post.order_by(:number_of_comments)

# or if you didn't:
Post.order_by { |post| post.comments.count }
```

#### `count`

like in AR

#### `take`, `drop`, `first`, `last`

like in Ruby.


