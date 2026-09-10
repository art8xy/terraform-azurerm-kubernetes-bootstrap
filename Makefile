TERRAFORM := terraform
TFSWITCH := tfswitch
VERSION := 1.16.1

example ?= basic
workdir ?= $(CURDIR)/examples/$(example)

TF := $(TERRAFORM) -chdir=$(workdir)

define req
	@which $(1) > /dev/null 2>&1 || (echo "Error: $(1) is not installed. Please install it and try again." && exit 1)
endef

req:
	@$(call req,$(TFSWITCH))

switch: req
	@$(TFSWITCH) $(VERSION)

fmt: switch
	@$(TF) fmt -recursive $(CURDIR)

init: fmt
	@$(TF) init 

plan: init
	@$(TF) plan

apply: init
	@$(TF) apply

destroy: init
	@$(TF) destroy

clean:
	@rm -rf .build
	@rm -rf bootstrap.zip
	@find . -name ".terraform" -type d -exec rm -rf {} +
	@find . -name ".terraform.lock.hcl" -type f -exec rm -f {} +
	@find . -name "terraform.tfstate" -type f -exec rm -f {} +
	@find . -name "terraform.tfstate.backup" -type f -exec rm -f {} +
