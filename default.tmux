# Default values for the plugin
set-option -goq @tmux_kubecontext_kubeconfig ""
set-option -goq @tmux_kubecontext_kubectl_binary "kubectl"

set-option -goq @tmux_kubecontext_symbol_enable "true"
set-option -goq @tmux_kubecontext_symbol "⎈"
set-option -goq @tmux_kubecontext_symbol_fg_color ""

set-option -goq @tmux_kubecontext_context_fg_color ""

set-option -goq @tmux_kubecontext_separator ":"
set-option -goq @tmux_kubecontext_separator_fg_color ""

set-option -goq @tmux_kubecontext_namespace_enable true
set-option -goq @tmux_kubecontext_namespace_fg_color ""

set-option -goq @tmux_kubecontext_error_enable true
set-option -goq @tmux_kubecontext_error_prefix "[E]"
set-option -goq @tmux_kubecontext_error_fg_color ""

set-option -goq @tmux_kubecontext_lock_enable "false"
