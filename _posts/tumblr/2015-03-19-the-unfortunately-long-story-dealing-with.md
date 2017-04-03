---
layout: post
title: Python Fails - Multipart file uploads in Python
date: '2015-03-19T12:38:13-07:00'
cover: 'assets/images/cover_python.png'
subclass: 'post tag-fiction'
tags:
- python
- file-upload
tumblr_url: http://blog.thesparktree.com/post/114053773684/the-unfortunately-long-story-dealing-with
categories: 'analogj'
navigation: True
logo: 'assets/logo-dark.png'
---

Python: Its a scripting language you can basically do anything with. Err.. most things, some are a real pain in the ass out of the box.

Before we start, a caveat. I'm working with Python 2.7, if you're using Python 3.x, you may be able to use `urllib3`, which I've heard good things about. If you're too lazy to look into it, the code I include below should still work for you.


I found myself needing to upload a file via Python. Like any <strike>expert</strike> developer I began searching the compendium of human knowledge that is StackOverflow.

I found many results, all of which looked promising at first glance.

- [Using MultipartPostHandler to POST form-data with Python](https://stackoverflow.com/questions/680305/using-multipartposthandler-to-post-form-data-with-python)
- [Send file using POST from a Python script](https://stackoverflow.com/questions/68477/send-file-using-post-from-a-python-script)
- [How to send a “multipart/form-data” with requests in python?](https://stackoverflow.com/questions/12385179/how-to-send-a-multipart-form-data-with-requests-in-python)

I quickly realized that almost all questions referenced the incredible ["requests"](http://docs.python-requests.org/en/latest/) , ["poster"](http://atlee.ca/software/poster/) or other third party modules. While any sane developer would just bask in their single handed victory and then start on the next item of their to-do list, I'm a glutton for punishment. I needed to do my multipart upload like a real <strike>man</strike> developer: python standard libraries only.

Luckily I was able to find a simple looking snippet that only used [urllib2](http://code.activestate.com/recipes/146306-http-client-to-post-using-multipartform-data/) something I was familiar with. Huzzah! With a few test files in hand, I began testing my shiny new script. Alas it was all for naught, the multipart upload script would only work for some files, and would fail horribly for others.

The error message I was getting `UnicodeDecodeError: 'utf8' codec can't decode byte 0x8d in position 516: invalid start byte` helped clue me into the fact that the files that failed were binary files rather than simple text documents. It seems the simple script was concatenating the file data directly into a string, at which point my binary files threw up. Ah the joys of file encoding.

I tried a quick and proven fix: when in doubt, force "utf-8". As the `open` command doesn't allow us to force encoding, I switched to using the built-in `codecs` module. I tried a few different file encodings before doing a naive search for ["How to detect the encoding of a file"](https://programmers.stackexchange.com/questions/187169/how-to-detect-the-encoding-of-a-file) at which point I felt like a real idiot as I saw the answer:
> Files generally indicate their encoding with a file header. ... However, even reading the header you can never be sure what encoding a file is really using.

Great, back to square one.

The most obvious solution was to rewrite the uploader script so that it used a binary buffer to store the file data, something that would be much more intelligent. I quickly hacked together a quick version of the file uploader script, but made sure to use `BytesIO` to store the form data, rather than joining all the data into a string. Again, no joy. Now I was getting the same error, but deep inside the `urllib2` function. Ugh, that means that internally `urllib2` is converting my beautiful binary buffer into a string. Son of a.

Screw it. I'll just rewrite it using `http`.

```python
import mimetools
import mimetypes
import io
import http
import json


form = MultiPartForm()
form.add_field("form_field", "my awesome data")

# Add a fake file
form.add_file(key, os.path.basename(filepath),
	fileHandle=codecs.open("/path/to/my/file.zip", "rb"))

# Build the request
url = "http://www.example.com/endpoint"
schema, netloc, url, params, query, fragments = urlparse.urlparse(url)

try:
	form_buffer =  form.get_binary().getvalue()
	http = httplib.HTTPConnection(netloc)
	http.connect()
	http.putrequest("POST", url)
	http.putheader('Content-type',form.get_content_type())
	http.putheader('Content-length', str(len(form_buffer)))
	http.endheaders()
	http.send(form_buffer)
except socket.error, e:
	raise SystemExit(1)

r = http.getresponse()
if r.status == 200:
	return json.loads(r.read())
else:
	print('Upload failed (%s): %s' % (r.status, r.reason))

class MultiPartForm(object):
	"""Accumulate the data to be used when posting a form."""

	def __init__(self):
		self.form_fields = []
		self.files = []
		self.boundary = mimetools.choose_boundary()
		return

	def get_content_type(self):
		return 'multipart/form-data; boundary=%s' % self.boundary

	def add_field(self, name, value):
		"""Add a simple field to the form data."""
		self.form_fields.append((name, value))
		return

	def add_file(self, fieldname, filename, fileHandle, mimetype=None):
		"""Add a file to be uploaded."""
		body = fileHandle.read()
		if mimetype is None:
			mimetype = mimetypes.guess_type(filename)[0] or 'application/octet-stream'
		self.files.append((fieldname, filename, mimetype, body))
		return

	def get_binary(self):
		"""Return a binary buffer containing the form data, including attached files."""
		part_boundary = '--' + self.boundary

		binary = io.BytesIO()
		needsCLRF = False
		# Add the form fields
		for name, value in self.form_fields:
			if needsCLRF:
				binary.write('\r\n')
			needsCLRF = True

			block = [part_boundary,
			  'Content-Disposition: form-data; name="%s"' % name,
			  '',
			  value
			]
			binary.write('\r\n'.join(block))

		# Add the files to upload
		for field_name, filename, content_type, body in self.files:
			if needsCLRF:
				binary.write('\r\n')
			needsCLRF = True

			block = [part_boundary,
			  str('Content-Disposition: file; name="%s"; filename="%s"' % \
			  (field_name, filename)),
			  'Content-Type: %s' % content_type,
			  ''
			  ]
			binary.write('\r\n'.join(block))
			binary.write('\r\n')
			binary.write(body)


		# add closing boundary marker,
		binary.write('\r\n--' + self.boundary + '--\r\n')
		return binary
```