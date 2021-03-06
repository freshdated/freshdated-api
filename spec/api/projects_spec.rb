require 'spec_helper'

describe Freshdated::API::Projects do
  include Rack::Test::Methods

  def app
    Freshdated::API::Projects
  end

  describe "projects" do
    let!(:projects) do
      FactoryGirl.create_list(:project, 3)
    end
    let!(:project) do
      projects.last
    end

    describe "GET /v1/projects.json" do
      it "returns all projects" do
        get "/v1/projects.json"
        expect(last_response.body).to eq(projects.to_json)
      end
    end

    describe "GET /v1/projects/:id.json" do
      let(:valid_id) { project.id }
      it "returns specified project" do
        get "/v1/projects/#{valid_id}.json"
        expect(last_response.body).to eq(project.to_json)
      end

      context "project not found" do
        let(:not_found_id) { "invalid" }
        it "returns 404" do
          get "/v1/projects/#{not_found_id}.json"
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe "POST /v1/projects" do
      let(:post_data) do
        post "/v1/projects", data
      end

      context "valid data" do
        let(:data) {{title: "New Project", repository:  "New Repository"}}

        it "increments number of projects" do
          expect{ post_data }.to change{ Project.count }.from(3).to(4)
        end

        it "adds new project" do
          expect{ post_data }.to change{ Project.all.last.title }.from(Project.all.last.title).to("New Project")
        end

        it "returns status 201" do
          post_data
          expect(last_response.status).to eq(201)
        end
      end

      context "invalid data" do
        let(:data) {{title: 'Test'}}

        it "returns status 400" do
          post_data
          expect(last_response.status).to eq(400)
        end

        it "returns error message" do
          post_data
          expect(last_response.body).to eq({"error" => "repository is missing"}.to_json)
        end
      end
    end
  end

  describe "projects/packages" do
    let!(:project)          { FactoryGirl.create(:project) }
    let!(:package_system)   { FactoryGirl.create(:package_system) }
    let!(:current_packages) { FactoryGirl.create_list(:package, 2, package_system: package_system) }

    describe "GET /v1/projects/:id/packages" do
      let!(:project_packages) { FactoryGirl.create_list(:project_package, 2, project: project, package: FactoryGirl.create(:package, {package_system: package_system})) }
      let(:get_data)          { get "/v1/projects/#{project.id}/packages" }

      it "returns status 200" do
        get_data
        expect(last_response.status).to eq(200)
      end

      it "returns project packages" do
        get_data
        returned_packages = JSON.parse(last_response.body)
        expect(returned_packages.size).to eq(2)
        returned_packages.each do |pkg|
          expect(pkg.keys).to eq(["id", "package_id", "project_id", "version", "status", "system", "name", "last_version"])
        end
      end
    end

    describe "PUT /v1/projects/:id/packages" do
      let(:data) do
        {system: package_system.name, packages: [{name: 'rest-client', version: '1.0.1'}, {name: 'rspec', version: '2.0.0'}]}
      end
      let(:put_data)          { put "/v1/projects/#{project.id}/packages", data }

      context "updating sucessfully" do
        before do
          allow(Project).to receive(:find!).and_return(project)
          allow(project).to receive(:update_packages_for!)
          put_data
        end

        it "updates the packages" do
          expect(project).to have_received(:update_packages_for!).with(package_system, data[:packages])
        end

        it "returns 200" do
          put_data
          expect(last_response.status).to eq(200)
        end
      end
    end
  end
end
