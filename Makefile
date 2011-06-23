.PHONY: default
default:
	@echo No default target && false

PACKAGE_REPOS:=\
    eldap-wrapper \
    erlando \
    erlang-rfc4627-wrapper \
    hstcp \
    mochiweb-wrapper \
    rabbitmq-auth-backend-ldap \
    rabbitmq-auth-mechanism-ssl \
    rabbitmq-external-exchange \
    rabbitmq-federation \
    rabbitmq-ha-test \
    rabbitmq-jsonrpc \
    rabbitmq-jsonrpc-channel \
    rabbitmq-jsonrpc-channel-examples \
    rabbitmq-management \
    rabbitmq-management-agent \
    rabbitmq-metronome \
    rabbitmq-mochiweb \
    rabbitmq-shovel \
    rabbitmq-stomp \
    rabbitmq-toke \
    toke \
    webmachine-wrapper

REPOS:=rabbitmq-server rabbitmq-erlang-client rabbitmq-codegen $(PACKAGE_REPOS)

BRANCH:=default

HG_CORE_REPOBASE:=$(shell dirname `hg paths default 2>/dev/null` 2>/dev/null)
ifndef HG_CORE_REPOBASE
HG_CORE_REPOBASE:=http://hg.rabbitmq.com/
endif

VERSION:=0.0.0

#----------------------------------

all:
	$(MAKE) -f all-packages.mk all-packages VERSION=$(VERSION)

test:
	$(MAKE) -f all-packages.mk test-all-packages VERSION=$(VERSION)

release:
	$(MAKE) -f all-packages.mk all-releasable VERSION=$(VERSION)

clean:
	$(MAKE) -f all-packages.mk clean-all-packages

plugins-dist: release
	rm -rf $(PLUGINS_DIST_DIR)
	mkdir -p $(PLUGINS_DIST_DIR)
	$(MAKE) -f all-packages.mk copy-releasable VERSION=$(VERSION) $(PLUGINS_DIST_DIR)=$(PLUGINS_DIST_DIR)

#----------------------------------
# Convenience aliases

.PHONY: co
co: checkout

.PHONY: ci
ci: checkin

.PHONY: up
up: update

.PHONY: st
st: status

.PHONY: up_c
up_c: named_update

#----------------------------------

$(REPOS):
	hg clone $(HG_CORE_REPOBASE)/$@

.PHONY: checkout
checkout: $(REPOS)

#----------------------------------
# Subrepository management


# $(1) is the target
# $(2) is the target dependency
# $(3) is the target body
define repo_target

.PHONY: $(1)
$(1): $(2)
	$(3)

endef

# $(1) is the list of repos
# $(2) is the suffix
# $(3) is the target dependency
# $(4) is the target body
define repo_targets
$(foreach REPO,$(1),$(call repo_target,$(REPO)+$(2),$(patsubst %,$(3),$(REPO)),$(4)))
endef

# Do not allow status to fork with -j otherwise output will be garbled
.PHONY: status
status: checkout
	$(foreach DIR,. $(REPOS), \
		(cd $(DIR); OUT=$$(hg st -mad); \
		if \[ ! -z "$$OUT" \]; then echo "\n$(DIR):\n$$OUT"; fi) &&) true

.PHONY: pull
pull: $(foreach DIR,. $(REPOS),$(DIR)+pull)

$(eval $(call repo_targets,. $(REPOS),pull,| %,\
	(cd $$(patsubst %+pull,%,$$@) && hg pull)))

.PHONY: update
update: $(foreach DIR,. $(REPOS),$(DIR)+update)

$(eval $(call repo_targets,. $(REPOS),update,%+pull,\
	(cd $$(patsubst %+update,%,$$@) && hg up)))

.PHONY: named_update
named_update: $(foreach DIR,. $(REPOS),$(DIR)+named_update)

$(eval $(call repo_targets,. $(REPOS),named_update,%+pull,\
	(cd $$(patsubst %+named_update,%,$$@) && hg up -C $(BRANCH))))

.PHONY: tag
tag: $(foreach DIR,. $(PACKAGE_REPOS),$(DIR)+tag)

$(eval $(call repo_targets,. $(PACKAGE_REPOS),tag,| %,\
	(cd $$(patsubst %+tag,%,$$@) && hg tag $(TAG))))

.PHONY: push
push: $(foreach DIR,. $(REPOS),$(DIR)+push)

$(eval $(call repo_targets,. $(REPOS),push,| %,\
	(cd $$(patsubst %+push,%,$$@) && hg push -f)))

.PHONY: checkin
checkin: $(foreach DIR,. $(REPOS),$(DIR)+checkin)

$(eval $(call repo_targets,. $(REPOS),checkin,| %,\
	(cd $$(patsubst %+checkin,%,$$@) && hg ci)))
