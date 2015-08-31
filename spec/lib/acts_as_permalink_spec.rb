require 'spec_helper'

describe Acts::Permalink do
  describe "default attributes" do

    let(:post) { Post.create title: "Test post 1!" }

    it "sets the normal permalink" do
      expect(post.permalink).to eq("test-post-1")
    end

    let(:post1) { Post.create title: "collision" }
    let(:post2) { Post.create title: "collision" }

    it "avoids a collision" do
      expect(post1.permalink).to eq("collision")
      expect(post2.permalink).to eq("collision1")
    end

    let(:long_post) { Post.create title: ("a" * 250) }

    it "shortens permalinks to a maximum length" do
      expect(long_post.permalink).to eq("a" * 60)
    end

  end

  describe "single table inheritance" do

    let(:specific_thing) { SpecificThing.create title: "the title" }

    it "creates the permalink for the subclass" do
      expect(specific_thing.permalink).to eq("the-title")
    end

  end

  describe "custom attributes" do

    let(:other_post) { OtherPost.create other_title: "Other post" }

    it "can be configured to use a column other thand the default" do
      expect(other_post.other_permalink).to eq("other-post")
    end
    
  end

end