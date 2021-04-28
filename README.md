# tmux-kubecontext

tmux-kubecontext is a script to display kubernetes context on tmux status bar.
This is inspired by [kube-ps1](https://github.com/jonmosco/kube-ps1), [kube-tmux](https://github.com/jonmosco/kube-tmux), and [zsh-kubectl-prompt](https://github.com/superbrothers/zsh-kubectl-prompt).

## Usage

Clone this repository to your `$HOME/.tmux-kubecontext`, and add the following line to your `~/.tmux.conf`:

```sh
# Update interval is up to you
set -g status-interval 5
set -g status-right "#(/bin/bash $HOME/.tmux-kubecontext/tmux-kubecontext.tmux)"
```

## Customization

tmux-kubecontext can be configured with defined tmux options.
If you'd like to configure, set below options in your `${HOME}/.tmux.conf`.
| flag | default | purpose |
|---|---|---|
| @tmux_kubecontext_kubectl_binary     | `kubectl` | kubectl binary path |
| @tmux_kubecontext_symbol_enable      | `true`    | Show symbol or not |
| @tmux_kubecontext_symbol             | `⎈`       | Symbol before context is shown |
| @tmux_kubecontext_symbol_fg_color    |           | Symbol foreground color. Default is configured in tmux style. |
| @tmux_kubecontext_context_fg_color   |           | Context foreground color. Default is configured in tmux style. |
| @tmux_kubecontext_separator          | `:`       | Separator for context and namespace |
| @tmux_kubecontext_separator_fg_color |           | Separator foreground color. Default is configured in tmux style. |
| @tmux_kubecontext_namespace_enable   | `true`    | Show namespace or not |
| @tmux_kubecontext_error_enable       | `true`    | Show error or not |
| @tmux_kubecontext_error_prefix       | `[E]`     | Error message prefix |
| @tmux_kubecontext_error_fg_color     |           | Symbol foreground color. Default is configured in tmux style. |
| @tmux_kubecontext_lock_enable        | `false`   | Lock to run tmux-kubecontext or not. Maybe useful in case that this is called many times in a short time. |

## How to refer KUBECONFIG on the current active pane

To my knowledge, script executed in tmux status bar can't refer active pane environment variables.
For that reason, tmux-kubecontext provides the solution to propagate KUBECONFIG env with bash or zsh hook feature.
If you are a zsh user, you can set precmd hook to update KUBECONFIG used by tmux-kubecontext like the below snippet:

```sh
autoload -Uz add-zsh-hook

function tmux_hook() {
  if [[ -z ${TMUX} ]]; then
    return
  fi
  tmux set-option -gq "@tmux_kubecontext_kubeconfig_#{pane_id}-#{session_id}-#{window_id}" "${KUBECONFIG}"
}

add-zsh-hook precmd tmux_hook
```

## Licence

This script is released under [the Apache License Version 2.0](./LICENSE).
