import{_ as l,o as t,c as n,j as a,a as s}from"./chunks/framework.DhH8_2wW.js";const m=JSON.parse('{"title":"Full stack","description":"","frontmatter":{},"headers":[],"relativePath":"markdown-publish--full-stack.md","filePath":"markdown-publish--full-stack.md"}'),o={name:"markdown-publish--full-stack.md"};function i(r,e,c,d,u,p){return t(),n("div",null,[...e[0]||(e[0]=[a("h1",{id:"full-stack",tabindex:"-1"},[s("Full stack "),a("a",{class:"header-anchor",href:"#full-stack","aria-label":'Permalink to "Full stack"'},"​")],-1),a("p",null,"To install all modules associated with publishing documentation with this class (including converting Docbook XML articles to Markdown and publishing) you can optionally install the full stack of dependencies. Not needed for basic operations but will ensure all commands function as expected:",-1),a("pre",null,[a("code",null,`# Install required system packages. Fedora given, use appropriate for your
# distro. Sudo if required.
#
dnf install -y cpanminus mkdocs-material expat-devel xmllint xlstproc pandoc git

# Install all modules associated with Markdown::Publish, including MakeMaker helpers
#
cpanm Task::Markdown::Publish
`)],-1)])])}const f=l(o,[["render",i]]);export{m as __pageData,f as default};
