import { useEffect, useState } from 'react'
import { zodResolver } from '@hookform/resolvers/zod'
import { addHours, format, isSameDay } from 'date-fns'
import { CalendarIcon } from 'lucide-react'
import { Controller, useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod'
import { api } from '@/lib/api'

import { ParticipantPicker } from '@/components/participant-picker'
import { Button } from '@/components/ui/button'
import { Calendar } from '@/components/ui/calendar'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Textarea } from '@/components/ui/textarea'
import { useCreateMeeting, useUpdateMeeting } from '@/hooks/queries'
import type { Meeting } from '@/lib/api'

const timePattern = /^\d{2}:\d{2}$/

const meetingSchema = z
  .object({
    title: z.string().trim().min(1, 'Title is required').max(200),
    description: z.string(),
    date: z.date({ error: 'Pick a date' }),
    startTime: z.string().regex(timePattern, 'Enter a start time'),
    endTime: z.string().regex(timePattern, 'Enter an end time'),
    place: z.string().trim().min(1, 'Place is required').max(200),
    participantIds: z.array(z.string()),
  })
  .refine((v) => v.endTime > v.startTime, {
    message: 'End time must be after start time',
    path: ['endTime'],
  })

type MeetingFormValues = z.input<typeof meetingSchema>

const defaultValues: MeetingFormValues = {
  title: '',
  description: '',
  date: undefined as unknown as Date,
  startTime: '10:00',
  endTime: '11:00',
  place: '',
  participantIds: [],
}

function toFormValues(meeting: Meeting): MeetingFormValues {
  const start = new Date(meeting.starts_at)
  return {
    title: meeting.title,
    description: meeting.description,
    date: start,
    startTime: format(start, 'HH:mm'),
    endTime: format(new Date(meeting.ends_at), 'HH:mm'),
    place: meeting.place,
    participantIds: meeting.participants.map((p) => p.id),
  }
}

/** A new meeting starting at `start` and lasting an hour (cut off at midnight). */
function newMeetingValues(start: Date): MeetingFormValues {
  const end = addHours(start, 1)
  return {
    ...defaultValues,
    date: start,
    startTime: format(start, 'HH:mm'),
    endTime: isSameDay(start, end) ? format(end, 'HH:mm') : '23:59',
  }
}

function combine(date: Date, time: string): string {
  const [hours, minutes] = time.split(':').map(Number)
  const result = new Date(date)
  result.setHours(hours, minutes, 0, 0)
  return result.toISOString()
}

type Props = {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** The meeting to edit; omit to create a new one. */
  meeting?: Meeting | null
  /** Prefilled start of a new meeting, e.g. the calendar slot that was clicked. */
  initialStart?: Date | null
}

export function MeetingFormDialog({ open, onOpenChange, meeting, initialStart }: Props) {
  const [datePickerOpen, setDatePickerOpen] = useState(false)
  const [agendaText, setAgendaText] = useState('')
  const [isParsingAgenda, setIsParsingAgenda] = useState(false)
  const createMeeting = useCreateMeeting()
  const updateMeeting = useUpdateMeeting()
  const isEditing = Boolean(meeting)
  const isPending = createMeeting.isPending || updateMeeting.isPending
  const form = useForm<MeetingFormValues>({
    resolver: zodResolver(meetingSchema),
    defaultValues,
  })

  useEffect(() => {
    if (!open) return
    if (meeting) form.reset(toFormValues(meeting))
    else form.reset(initialStart ? newMeetingValues(initialStart) : defaultValues)
  }, [open, meeting, initialStart, form])

  const close = (next: boolean) => onOpenChange(next)
  const parseAgenda = async () => {
    if (!agendaText.trim()) {
      toast.error('Paste the agenda text first')
      return
    }

    setIsParsingAgenda(true)
    try {
      const result = await api.parseAgenda(
        agendaText.trim(),
        format(new Date(), 'yyyy-MM-dd'),
        'Europe/Kyiv',
      )
      const agenda = result.agenda
      const start = new Date(agenda.starts_at)

      form.setValue('title', agenda.title, { shouldValidate: true })

      if (!Number.isNaN(start.getTime())) {
        form.setValue('date', start, { shouldValidate: true })
        form.setValue('startTime', format(start, 'HH:mm'), {
          shouldValidate: true,
        })
        const duration = agenda.duration_minutes ?? 60
        const end = addHours(start, duration / 60)
        form.setValue(
          'endTime',
          isSameDay(start, end) ? format(end, 'HH:mm') : '23:59',
          { shouldValidate: true },
        )
      }

      const description = [
        ...agenda.items.map((item) => `• ${item.topic}`),
        ...agenda.action_items.map(
          (item) => `Action: ${item.task}${item.owner ? ` — ${item.owner}` : ''}`,
        ),
      ].join('\n')

      form.setValue('description', description, { shouldValidate: true })
      toast.success('Agenda parsed. Review the fields before saving.')
    } catch (error) {
      toast.error(error instanceof Error ? error.message : 'Could not parse agenda')
    } finally {
      setIsParsingAgenda(false)
    }
  }

  const onSubmit = form.handleSubmit((values) => {
    const data = {
      title: values.title.trim(),
      description: values.description.trim(),
      starts_at: combine(values.date, values.startTime),
      ends_at: combine(values.date, values.endTime),
      place: values.place.trim(),
      participant_ids: values.participantIds,
    }
    const callbacks = {
      onSuccess: (saved: Meeting) => {
        toast.success(`Meeting "${saved.title}" ${isEditing ? 'updated' : 'created'}`)
        close(false)
      },
      onError: (error: Error) => form.setError('root', { message: error.message }),
    }
    if (meeting) {
      updateMeeting.mutate({ id: meeting.id, ...data }, callbacks)
    } else {
      createMeeting.mutate(data, callbacks)
    }
  })

  return (
    <Dialog open={open} onOpenChange={close}>
      <DialogContent className="max-h-[calc(100svh-2rem)] grid-rows-[auto_minmax(0,1fr)_auto] sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{isEditing ? 'Edit meeting' : 'Add meeting'}</DialogTitle>
          <DialogDescription>Fill in the details and pick who takes part.</DialogDescription>
        </DialogHeader>

        {/* Only the fields scroll; header and footer stay put on short screens. */}
        <form
          id="meeting-form"
          onSubmit={onSubmit}
          noValidate
          className="-mx-6 overflow-y-auto px-6 py-1"
        >
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="agenda-text">Paste an agenda</FieldLabel>
              <Textarea
                id="agenda-text"
                rows={4}
                placeholder="Paste meeting notes or an agenda here..."
                value={agendaText}
                onChange={(event) => setAgendaText(event.target.value)}
              />
              <Button
                type="button"
                variant="outline"
                disabled={isParsingAgenda || !agendaText.trim()}
                onClick={parseAgenda}
              >
                {isParsingAgenda ? 'Parsing...' : 'Parse agenda with AI'}
              </Button>
            </Field>
            <Controller
              name="title"
              control={form.control}
              render={({ field, fieldState }) => (
                <Field data-invalid={fieldState.invalid}>
                  <FieldLabel htmlFor="meeting-title">Title</FieldLabel>
                  <Input id="meeting-title" aria-invalid={fieldState.invalid} {...field} />
                  <FieldError errors={[fieldState.error]} />
                </Field>
              )}
            />

            <Controller
              name="description"
              control={form.control}
              render={({ field }) => (
                <Field>
                  <FieldLabel htmlFor="meeting-description">Description</FieldLabel>
                  <Textarea id="meeting-description" rows={3} {...field} />
                </Field>
              )}
            />

            <div className="grid gap-4 sm:grid-cols-[1fr_auto_auto]">
              <Controller
                name="date"
                control={form.control}
                render={({ field, fieldState }) => (
                  <Field data-invalid={fieldState.invalid}>
                    <FieldLabel htmlFor="meeting-date">Date</FieldLabel>
                    <Popover open={datePickerOpen} onOpenChange={setDatePickerOpen}>
                      <PopoverTrigger asChild>
                        <Button
                          id="meeting-date"
                          type="button"
                          variant="outline"
                          aria-invalid={fieldState.invalid}
                          className="justify-start font-normal"
                        >
                          <CalendarIcon />
                          {field.value ? (
                            format(field.value, 'EEE, d MMM yyyy')
                          ) : (
                            <span className="text-muted-foreground">Pick a date</span>
                          )}
                        </Button>
                      </PopoverTrigger>
                      <PopoverContent className="w-auto p-0" align="start">
                        <Calendar
                          mode="single"
                          selected={field.value}
                          onSelect={(date) => {
                            field.onChange(date)
                            setDatePickerOpen(false)
                          }}
                          autoFocus
                        />
                      </PopoverContent>
                    </Popover>
                    <FieldError errors={[fieldState.error]} />
                  </Field>
                )}
              />
              <Controller
                name="startTime"
                control={form.control}
                render={({ field, fieldState }) => (
                  <Field data-invalid={fieldState.invalid}>
                    <FieldLabel htmlFor="meeting-start">Start</FieldLabel>
                    <Input
                      id="meeting-start"
                      type="time"
                      aria-invalid={fieldState.invalid}
                      {...field}
                    />
                    <FieldError errors={[fieldState.error]} />
                  </Field>
                )}
              />
              <Controller
                name="endTime"
                control={form.control}
                render={({ field, fieldState }) => (
                  <Field data-invalid={fieldState.invalid}>
                    <FieldLabel htmlFor="meeting-end">End</FieldLabel>
                    <Input
                      id="meeting-end"
                      type="time"
                      aria-invalid={fieldState.invalid}
                      {...field}
                    />
                    <FieldError errors={[fieldState.error]} />
                  </Field>
                )}
              />
            </div>

            <Controller
              name="place"
              control={form.control}
              render={({ field, fieldState }) => (
                <Field data-invalid={fieldState.invalid}>
                  <FieldLabel htmlFor="meeting-place">Place</FieldLabel>
                  <Input
                    id="meeting-place"
                    placeholder="Room, address, or video link"
                    aria-invalid={fieldState.invalid}
                    {...field}
                  />
                  <FieldError errors={[fieldState.error]} />
                </Field>
              )}
            />

            <Controller
              name="participantIds"
              control={form.control}
              render={({ field, fieldState }) => (
                <Field data-invalid={fieldState.invalid}>
                  <FieldLabel htmlFor="meeting-participants">Participants</FieldLabel>
                  <ParticipantPicker
                    id="meeting-participants"
                    value={field.value}
                    onChange={field.onChange}
                    invalid={fieldState.invalid}
                  />
                  <FieldError errors={[fieldState.error]} />
                </Field>
              )}
            />

            {form.formState.errors.root && (
              <FieldError>{form.formState.errors.root.message}</FieldError>
            )}
          </FieldGroup>
        </form>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => close(false)}>
            Cancel
          </Button>
          <Button type="submit" form="meeting-form" disabled={isPending}>
            {isPending ? 'Saving...' : isEditing ? 'Save changes' : 'Add meeting'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
