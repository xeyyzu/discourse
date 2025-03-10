import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";

const SLUG_MAX_LENGTH = 100;

export default class ChatModalEditChannelName extends Component {
  @service chatApi;
  @service router;
  @service siteSettings;

  @tracked editedName = this.channel.title;
  @tracked editedSlug = this.channel.slug;
  @tracked
  autoGeneratedSlug = this.channel.slug ?? slugifyChannel(this.channel);
  @tracked flash;

  #generateSlugHandler = null;

  get channel() {
    return this.args.model;
  }

  get isSaveDisabled() {
    return (
      (this.channel.title === this.editedName &&
        this.channel.slug === this.editedSlug) ||
      this.editedName?.length > this.siteSettings.max_topic_title_length ||
      this.editedSlug?.length > SLUG_MAX_LENGTH
    );
  }

  @action
  async onSave() {
    try {
      const result = await this.chatApi.updateChannel(this.channel.id, {
        name: this.editedName,
        slug: this.editedSlug || this.autoGeneratedSlug || this.channel.slug,
      });

      this.channel.title = result.channel.title;
      this.channel.slug = result.channel.slug;
      await this.args.closeModal();
      this.router.replaceWith("chat.channel", ...this.channel.routeModels);
    } catch (error) {
      this.flash = extractError(error);
    }
  }

  @action
  onChangeChatChannelName(event) {
    this.flash = null;
    this.#debouncedGenerateSlug(event?.target?.value);
  }

  @action
  onChangeChatChannelSlug() {
    this.flash = null;
    this.#debouncedGenerateSlug(this.editedName);
  }

  #debouncedGenerateSlug(name) {
    cancel(this.#generateSlugHandler);
    this.autoGeneratedSlug = "";

    if (!name) {
      return;
    }

    this.#generateSlugHandler = discourseDebounce(
      this,
      this.#generateSlug,
      name,
      300
    );
  }

  async #generateSlug(name) {
    try {
      await ajax("/slugs.json", { type: "POST", data: { name } }).then(
        (response) => {
          this.autoGeneratedSlug = response.slug;
        }
      );
    } catch (error) {
      // eslint-disable-next-line no-console
      console.log(error);
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="chat-modal-edit-channel-name"
      @inline={{@inline}}
      @title={{i18n "chat.channel_edit_name_slug_modal.title"}}
      @flash={{this.flash}}
    >
      <:body>
        <div class="edit-channel-control">
          <label for="channel-name" class="edit-channel-label">
            {{i18n "chat.channel_edit_name_slug_modal.name"}}
          </label>
          <Input
            name="channel-name"
            class="chat-channel-edit-name-slug-modal__name-input"
            placeholder={{i18n
              "chat.channel_edit_name_slug_modal.input_placeholder"
            }}
            @type="text"
            @value={{this.editedName}}
            {{on "input" this.onChangeChatChannelName}}
          />
        </div>

        <div class="edit-channel-control">
          <label for="channel-slug" class="edit-channel-label">
            {{i18n "chat.channel_edit_name_slug_modal.slug"}}&nbsp;
            <DTooltip
              @icon="circle-info"
              @content={{i18n
                "chat.channel_edit_name_slug_modal.slug_description"
              }}
            />
          </label>
          <Input
            name="channel-slug"
            class="chat-channel-edit-name-slug-modal__slug-input"
            placeholder={{this.autoGeneratedSlug}}
            {{on "input" this.onChangeChatChannelSlug}}
            @type="text"
            @value={{this.editedSlug}}
          />
        </div>
      </:body>
      <:footer>
        <DButton
          @action={{this.onSave}}
          @label="save"
          @disabled={{this.isSaveDisabled}}
          class="btn-primary create"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
