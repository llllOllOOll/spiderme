const spider = @import("spider");

pub const config = spider.Config{
    // Where templates are, when they are read from disk: relative to the
    // directory the app is started in.
    .views_dir = "./src",
};
