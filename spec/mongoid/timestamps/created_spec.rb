# frozen_string_literal: true
# rubocop:todo all

require "spec_helper"

describe Mongoid::Timestamps::Created do

  describe ".included" do

    let(:quiz) do
      Quiz.new
    end

    let(:fields) do
      Quiz.fields
    end

    before do
      quiz.run_callbacks(:create)
      quiz.run_callbacks(:save)
    end

    it "adds created_at to the document" do
      expect(fields["created_at"]).to_not be_nil
    end

    it "does not add updated_at to the document" do
      expect(fields["updated_at"]).to be_nil
    end

    it "forces the created_at timestamps to UTC" do
      expect(quiz.created_at).to be_within(10).of(Time.now.utc)
    end
  end

  context "when the document is created" do

    let(:quiz) do
      Quiz.create!
    end

    it "runs the created callbacks" do
      expect(quiz.created_at).to_not be_nil
      expect(quiz.created_at).to be_within(10).of(Time.now.utc)
    end
  end

  context "when the document is destroyed" do
    let(:book) do
      Book.create!
    end

    before do
      Cover.before_save do
        destroy if title == "delete me"
      end
    end

    after do
      Cover.reset_callbacks(:save)
    end

    it "does not set the created_at timestamp" do
      book.covers << Cover.new(title: "delete me")
      expect {
        book.save
      }.not_to raise_error
    end
  end
end
