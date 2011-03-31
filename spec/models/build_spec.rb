require "spec_helper"

module Goldberg
  describe Build do
    it "should be able to fake the last version" do
      Build.nil.revision.should == ''
      Build.nil.should be_null
    end

    it "sorts correctly" do
      builds = [10, 9, 1, 500].map{|i| Factory(:build, :number => i)}
      builds.sort.map(&:number).map(&:to_i).should == [1, 9, 10, 500]
    end

    context "paths" do
      it "should know where to store the build artifacts on the file system" do
        project = Factory.build(:project, :name => "name")
        build = Factory.build(:build, :project => project, :number => 5)
        build.artifacts_path.should == File.join(project.path, "builds", "5")
      end
      
      [:change_list, :build_log].each do |artifact|
        it "should append build number to the project path to create a path for #{artifact}" do
          project = Factory.build(:project, :name => "name")
          build = Factory.build(:build, :project => project, :number => 5)
          build.send("#{artifact}_path").should == File.join(project.path, "builds", "5", artifact.to_s)
        end
      end
    end
    
    context "after create" do
      it "should create a directory for storing build artifacts" do
        project = Factory.build(:project, :name => 'ooga')
        build = Factory.build(:build, :project => project, :number => 5)
        FileUtils.should_receive(:mkdir_p).with(build.artifacts_path)
        build.save.should be_true
      end
    end
    
    context "before create" do
      it "should update the revision of the build if it is blank" do
        project = Factory.build(:project, :name => 'ooga')
        build = Factory.build(:build, :project => project, :number => 5, :revision => nil)
        project.repository.should_receive(:revision).and_return("new_sha")
        build.save
        build.reload
        build.revision.should == "new_sha"
      end
      
      it "should not update the build revision if it is already set" do
        project = Factory.build(:project, :name => 'ooga')
        build = Factory.build(:build, :project => project, :number => 5, :revision => "some_sha")
        build.save
        build.reload
        build.revision.should == "some_sha"
      end
    end
    
    context "changes" do
      it "should write a file with all the changes since the previous build" do
        project = Factory.build(:project, :name => 'ooga')
        build = Factory.build(:build, :project => project, :number => 5, :previous_build_revision => "old_sha", :revision => "new_sha")
        project.repository.should_receive(:change_list).with("old_sha", "new_sha").and_return("changes")
        file = mock(File)
        file.should_receive(:write).with("changes")
        File.should_receive(:open).with(build.change_list_path, "w+").and_yield(file)
        build.persist_change_list
      end
    end
    
    context "run" do
      let(:project) { Factory.build(:project) }
      let(:build) { Factory.create(:build, :project => project) }

      before(:each) do
        build.should_receive(:before_build)
      end
      
      it "should run the build command and update the build status" do
        Environment.should_receive(:system).and_return(true)
        build.run.should be_true
        build.reload
        build.status.should == "passed"
      end
      
      it "should set build status to failed if the build command fails" do
        Environment.should_receive(:system).and_return(false)
        build.run.should be_false
        build.reload
        build.status.should == "failed"
      end
    end
    
    context "before build" do
      it "should set build status to 'building' and persist the change list" do
        build = Factory.build(:build)
        build.should_receive(:persist_change_list)
        build.before_build
        build.reload.status.should == 'building'
      end
    end
  end
end
