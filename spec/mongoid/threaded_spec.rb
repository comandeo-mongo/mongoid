# frozen_string_literal: true
# rubocop:todo all

require "spec_helper"

describe Mongoid::Threaded do

  let(:object) do
    double
  end

  describe "#begin" do

    before do
      described_class.begin_execution("load")
    end

    after do
      described_class.stack("load").clear
    end

    it "adds a boolean to the load stack" do
      expect(described_class.stack("load")).to eq([ true ])
    end
  end

  describe "#executing?" do

    context "when loading is not set" do

      it "returns false" do
        expect(described_class).to_not be_executing(:load)
      end
    end

    context "when the stack has elements" do

      before do
        described_class.stack('load').push(true)
      end

      after do
        described_class.stack('load').clear
      end

      it "returns true" do
        expect(described_class).to be_executing(:load)
      end
    end

    context "when the stack has no elements" do

      before do
        described_class.stack('load').clear
      end

      it "returns false" do
        expect(described_class).to_not be_executing(:load)
      end
    end
  end

  describe "#stack" do

    context "when no stack has been initialized" do

      let(:loading) do
        described_class.stack("load")
      end

      it "returns an empty stack" do
        expect(loading).to be_empty
      end
    end

    context "when a stack has been initialized" do

      before do
        described_class.stack('load').push(true)
      end

      let(:loading) do
        described_class.stack("load")
      end

      after do
        described_class.stack('load').clear
      end

      it "returns the stack" do
        expect(loading).to eq([ true ])
      end
    end
  end

  describe "#exit" do

    before do
      described_class.begin_execution("load")
      described_class.exit_execution("load")
    end

    after do
      described_class.stack("load").clear
    end

    it "removes a boolean from the stack" do
      expect(described_class.stack("load")).to be_empty
    end
  end

  describe "#begin_validate" do

    let(:person) do
      Person.new
    end

    before do
      described_class.begin_validate(person)
    end

    after do
      described_class.exit_validate(person)
    end

    it "marks the document as being validated" do
      expect(described_class.validations_for(Person)).to eq([ person.id ])
    end
  end

  describe "#exit_validate" do

    let(:person) do
      Person.new
    end

    before do
      described_class.begin_validate(person)
      described_class.exit_validate(person)
    end

    it "unmarks the document as being validated" do
      expect(described_class.validations_for(Person)).to be_empty
    end
  end

  describe "#validated?" do

    let(:person) do
      Person.new
    end

    context "when the document is validated" do

      before do
        described_class.begin_validate(person)
      end

      after do
        described_class.exit_validate(person)
      end

      it "returns true" do
        expect(described_class.validated?(person)).to be true
      end
    end

    context "when the document is not validated" do

      it "returns false" do
        expect(described_class.validated?(person)).to be false
      end
    end
  end

  describe "#begin_autosave" do

    let(:person) do
      Person.new
    end

    before do
      described_class.begin_autosave(person)
    end

    after do
      described_class.exit_autosave(person)
    end

    it "marks the document as being autosaved" do
      expect(described_class.autosaves_for(Person)).to eq([ person.id ])
    end
  end

  describe "#exit_autosave" do

    let(:person) do
      Person.new
    end

    before do
      described_class.begin_autosave(person)
      described_class.exit_autosave(person)
    end

    it "unmarks the document as being autosaved" do
      expect(described_class.autosaves_for(Person)).to be_empty
    end
  end

  describe "#autosaved?" do

    let(:person) do
      Person.new
    end

    context "when the document is autosaved" do

      before do
        described_class.begin_autosave(person)
      end

      after do
        described_class.exit_autosave(person)
      end

      it "returns true" do
        expect(described_class.autosaved?(person)).to be true
      end
    end

    context "when the document is not autosaved" do

      it "returns false" do
        expect(described_class.autosaved?(person)).to be false
      end
    end
  end

  describe "#begin_without_default_scope" do

    let(:klass) do
      Appointment
    end

    after do
      described_class.exit_without_default_scope(klass)
    end

    it "adds the given class to the without_default_scope stack" do
      described_class.begin_without_default_scope(klass)

      expect(described_class.stack(:without_default_scope)).to include(klass)
    end
  end

  describe "#exit_without_default_scope" do

    let(:klass) do
      Appointment
    end

    before do
      described_class.begin_without_default_scope(klass)
    end

    it "removes the given class from the without_default_scope stack" do
      described_class.exit_without_default_scope(klass)

      expect(described_class.stack(:without_default_scope)).not_to include(klass)
    end
  end

  describe "#without_default_scope?" do

    let(:klass) do
      Appointment
    end

    context "when klass has begun without_default_scope" do

      before do
        described_class.begin_without_default_scope(klass)
      end

      after do
        described_class.exit_without_default_scope(klass)
      end

      it "returns true" do
        expect(described_class.without_default_scope?(klass)).to be(true)
      end
    end

    context "when klass has exited without_default_scope" do

      before do
        described_class.begin_without_default_scope(klass)
        described_class.exit_without_default_scope(klass)
      end

      it "returns false" do
        expect(described_class.without_default_scope?(klass)).to be(false)
      end
    end
  end

  describe "#get_session" do
    let(:session) do
      double('session')
    end

    context "without client specified" do
      before do
        described_class.set_session(session)
      end

      it 'returns session' do
        expect(described_class.get_session).to be(session)
      end
    end

    context 'with client' do
      let(:client) do
        double('client')
      end

      let(:client_session) do
        double('client_session')
      end

      before do
        # Set a 'global' thread session (deprecated)
        described_class.set_session(session)
        # Set a session for a client
        described_class.set_session(client_session, client: client)
      end

      it 'returns session' do
        expect(described_class.get_session(client: client)).to be(client_session)
      end
    end
  end

  describe '#clear_modified_documents' do
    let(:session) do
      double(Mongo::Session).tap do |session|
        allow(session).to receive(:in_transaction?).and_return(true)
      end
    end

    context 'when there are modified documents' do
      before do
        described_class.add_modified_document(session, Minim.new)
        described_class.clear_modified_documents(session)
      end

      it 'removes the documents and keys' do
        expect(described_class.modified_documents).to be_empty
      end
    end
  end
end
