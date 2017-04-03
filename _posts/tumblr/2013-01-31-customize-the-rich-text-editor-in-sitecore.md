---
layout: post
title: Customize the Rich Text Editor in Sitecore
date: '2013-01-31T20:53:45-08:00'
cover: 'assets/images/cover_sitecore.jpg'
subclass: 'post tag-fiction'
tags:
- Sitecore
- Telerik
- RadEditor
- C
- ".Net"
tumblr_url: http://blog.thesparktree.com/post/41988475011/customize-the-rich-text-editor-in-sitecore
categories: 'analogj'
navigation: True
logo: 'assets/logo.png'

---
We ran into some issues at work with sitecore. It seems that by default the Rich Text Editor that Sitecore uses, Telerik's RadEditor, will automatically convert `<b>` and `<i>` tags to `<strong>` and `<em>`. Our designers prefer to use the `<i>` tag for bootstrap's icon classes so we needed a fix.

First you need to create a class that inherits from `Sitecore.Shell.Controls.RichTextEditor.EditorConfiguration`

```cs
public class RichTextEditorCustomConfiguration: Sitecore.Shell.Controls.RichTextEditor.EditorConfiguration
{
	/// <summary>
	/// Initializes a new instance of the <see cref="RichTextEditorCustomConfiguration"></see> class.
	/// </summary>
	/// <param name="profile">The profile.
	public RichTextEditorCustomConfiguration(Item profile)
		: base(profile)
	{
	}

	/// <summary>
	/// Setup editor filters.
	/// </summary>
	protected override void SetupFilters()
	{
		//Disable the automatic conversion of <i> and <b> tags to <em> and <strong> for icon-* classes
		this.Editor.DisableFilter(EditorFilters.FixUlBoldItalic);
		this.Editor.DisableFilter(EditorFilters.MozEmStrong);
		this.Editor.EnableFilter(EditorFilters.IndentHTMLContent);
		base.SetupFilters();
	}
}
```

then you need to register the new class as the default editior configuration

    <setting name="HtmlEditor.DefaultConfigurationType" value="MyProject.RichTextEditorCustomConfiguration, MyProject"></setting>

That's it, it your tags will no longer be automatically converted.