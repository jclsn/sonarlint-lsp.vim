vim9script
# sonarlint-lsp.vim: SonarQube for IDE (sonarlint-ls) client for yegappan/lsp.

if exists('g:loaded_sonarlint_lsp')
  finish
endif
g:loaded_sonarlint_lsp = true

augroup SonarLintLsp
  autocmd!
  autocmd User LspSetup sonarlint#Setup()
  autocmd User LspAttached sonarlint#Attach()
augroup END
